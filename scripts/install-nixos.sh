#!/usr/bin/env bash

set -euo pipefail

# NixOS installer
#
# Picks a target machine from machines.toml at runtime, filtering to
# hosts whose hardware/<host>/hardware-configuration.nix matches the
# disk layout this script produces: GPT + EFI + btrfs root at
# /dev/disk/by-label/nixos, no LUKS.
#
# For hosts with a different layout (LUKS, UUID-pinned configs, etc.)
# the partitioning code below would need to grow new branches first.
#
# Override knobs:
#   DISK=/dev/vda  ./install-nixos.sh   # default is /dev/sda
#   TARGET_HOSTNAME=foo ./install-nixos.sh   # skip the menu
#   LOCAL_FLAKE=/run/media/usb/nix ./install-nixos.sh   # skip the git
#                                                       clone, copy from
#                                                       this path instead
#
# LOCAL_FLAKE exists for the case where the upstream repo is private
# (no anonymous clone) and you've staged the flake onto a USB stick or
# similar local mount alongside the NixOS installer ISO. When set, the
# script reads machines.toml / hardware/ from that path and copies it
# into /mnt verbatim — no network access required, no PAT/SSH key
# juggling on the live installer. When unset, the script falls back to
# cloning FLAKE_REPO over HTTPS (works for public repos out of the
# box).

DISK="${DISK:-/dev/sda}"
FLAKE_REPO="${FLAKE_REPO:-https://github.com/ajwells128/nixos-development-environment.git}" # TODO: Update this to point at _your_ repository (if public)
LOCAL_FLAKE="${LOCAL_FLAKE:-}"
USERNAME="andrew" # TODO: Update with your username
TMP_FLAKE="/tmp/nix-installer-flake"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Pre-flight
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. It will use sudo when needed."
fi
if ! command -v nixos-install >/dev/null; then
    error "This script must be run from a NixOS installer environment"
fi
if ! command -v git >/dev/null; then
    error "git is required (the NixOS installer ships it)"
fi

# Step 0: stage the flake at $TMP_FLAKE so we can read machines.toml
# and hardware/ before deciding what to install. Two modes:
#   - LOCAL_FLAKE set    -> copy from local path (no network).
#   - LOCAL_FLAKE unset  -> shallow clone from FLAKE_REPO (HTTPS).
rm -rf "$TMP_FLAKE"
if [[ -n "$LOCAL_FLAKE" ]]; then
    [[ -f "$LOCAL_FLAKE/flake.nix" ]] || error "LOCAL_FLAKE='$LOCAL_FLAKE' does not contain a flake.nix"
    log "Copying flake from local path: $LOCAL_FLAKE"
    # -a preserves perms/symlinks; trailing /. ensures dotfiles (.git,
    # .sops.yaml, .gitignore) come along, which `nix build` needs.
    cp -a "$LOCAL_FLAKE/." "$TMP_FLAKE"
else
    log "Fetching flake metadata from $FLAKE_REPO"
    git clone --depth=1 "$FLAKE_REPO" "$TMP_FLAKE" >/dev/null
fi

# TODO: Update this to be your flake hostname
TARGET_HOSTNAME=vmware-work

# Final summary + confirmation
echo
log "Target disk:     $DISK"
log "Target host:     $TARGET_HOSTNAME"
log "Username:        $USERNAME"
if [[ -n "$LOCAL_FLAKE" ]]; then
    log "Flake source:    $LOCAL_FLAKE (local)"
else
    log "Flake source:    $FLAKE_REPO"
fi
echo
read -p "This will DESTROY ALL DATA on $DISK. Continue? (yes/no): " -r
[[ $REPLY =~ ^yes$ ]] || error "Installation cancelled"

# Step 3: Partition
log "Partitioning $DISK"
sudo umount -R /mnt 2>/dev/null || true

# Kernel naming: devices whose name already ends in a digit (nvme0n1,
# mmcblk0, loopN) use a `p` separator for partitions; everything else
# (sda, vda) just appends the partition number directly.
case "$DISK" in
    *[0-9]) PART="${DISK}p" ;;
    *)      PART="${DISK}"  ;;
esac

sudo parted "$DISK" --script -- mklabel gpt
sudo parted "$DISK" --script -- mkpart ESP fat32 1MiB 513MiB
sudo parted "$DISK" --script -- set 1 esp on
sudo parted "$DISK" --script -- mkpart primary 513MiB 100%
sudo parted "$DISK" --script -- name 2 nixos

log "Formatting EFI partition (${PART}1)"
sudo mkfs.fat -F 32 -n nixos-boot "${PART}1"

log "Creating btrfs filesystem on ${PART}2"
sudo mkfs.btrfs -f -L nixos "${PART}2"

# Step 4: btrfs subvolumes
log "Creating btrfs subvolumes"
sudo mount /dev/disk/by-label/nixos /mnt
sudo btrfs subvolume create /mnt/@root
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@tmp
sudo btrfs subvolume create /mnt/@swap
sudo btrfs subvolume create /mnt/@snapshots
sudo btrfs subvolume create "/mnt/@home-$USERNAME"
sudo umount /mnt

# Step 5: mount everything for install
log "Mounting btrfs subvolumes"
BTRFS_OPTS="compress=zstd:1,noatime,space_cache=v2"
sudo mount -o "subvol=@root,$BTRFS_OPTS" /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/{home,nix,tmp,swap,boot,.snapshots}
sudo mkdir -p "/mnt/home/$USERNAME"
sudo mount -o "subvol=@home-$USERNAME,$BTRFS_OPTS" /dev/disk/by-label/nixos "/mnt/home/$USERNAME"
sudo mount -o "subvol=@nix,$BTRFS_OPTS"       /dev/disk/by-label/nixos /mnt/nix
sudo mount -o "subvol=@tmp,$BTRFS_OPTS"       /dev/disk/by-label/nixos /mnt/tmp
sudo mount -o "subvol=@snapshots,$BTRFS_OPTS" /dev/disk/by-label/nixos /mnt/.snapshots
sudo mount "${PART}1" /mnt/boot
sudo chown 1000:100 "/mnt/home/$USERNAME"

# Step 6: generate hardware config (mostly for fallback / inspection;
# the install uses the flake's per-host hardware-configuration.nix)
log "Generating hardware configuration"
sudo nixos-generate-config --root /mnt

# Step 7: place the flake on the target. Move the pre-cloned tree
# rather than re-fetching from the network.
log "Installing flake into /mnt/home/$USERNAME/projects/personal/nix"
sudo mkdir -p "/mnt/home/$USERNAME/projects/personal"
sudo cp -a "$TMP_FLAKE" "/mnt/home/$USERNAME/projects/personal/nix"
sudo chown -R 1000:100 "/mnt/home/$USERNAME/projects"

# /etc/nixos symlink for convenience inside the chroot.
sudo ln -sf "/home/$USERNAME/projects/personal/nix" /mnt/etc/nixos

log "Using filesystem labels: nixos (btrfs root) and nixos-boot (EFI)"

# Step 8: install
log "Installing NixOS for host $TARGET_HOSTNAME. If you see SSL errors, don't panic quite yet, let them pass"
log "If (when) prompted, enter a _temporary_ password for root. It will be overwritten later."
# TODO: If this encounters errors, use specify the cert bundle
# note: it appears they might both play an important role? Keep retrying if at first you fail, and alternate which one you use...
sudo nixos-install --root /mnt --flake "/mnt/home/$USERNAME/projects/personal/nix#$TARGET_HOSTNAME" \
|| sudo NIX_SSL_CERT_FILE=/mnt/home/$USERNAME/projects/personal/nix/bundle.crt nixos-install --root /mnt --flake "/mnt/home/$USERNAME/projects/personal/nix#$TARGET_HOSTNAME"

log "Installation completed successfully!"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                            INSTALLATION COMPLETE!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Host:           $TARGET_HOSTNAME
Disk:           $DISK
Flake location: /home/$USERNAME/projects/personal/nix
Username:       $USERNAME

Next steps:
1. Reboot: sudo reboot
2. Log in with your configured credentials
3. Home Manager runs automatically on first login

BTRFS subvolumes created:
  • @root             -> /
  • @home-$USERNAME   -> /home/$USERNAME
  • @nix              -> /nix
  • @tmp              -> /tmp
  • @snapshots        -> /.snapshots

To create snapshots:
  sudo btrfs subvolume snapshot /home/$USERNAME /.snapshots/home-\$(date +%Y%m%d-%H%M%S)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
