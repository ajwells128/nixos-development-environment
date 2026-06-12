{ lib, ... }:

{
  # Wayland GNOME session via GDM. GNOME 49 (NixOS 25.11) is Wayland-only;
  # legacy X11 apps still run through XWayland.
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
  };

  hardware.graphics.enable = true;

  # VMware Fusion on Apple Silicon presents virtio_gpu; modesetting drives it.
  services.xserver.videoDrivers = lib.mkDefault [ "modesetting" ];

  # Prefer native Wayland in Chromium/Electron apps.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
