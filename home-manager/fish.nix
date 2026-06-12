{
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  # Fish shell configuration
  programs.fish = {
    enable = true;

    # Aliases are commands fish silently substitutes — used here for
    # cases that override or transform a real command (eza-as-ls,
    # safer rm/cp/mv) where seeing the expansion every time is noise.
    shellAliases = {
      # Safety/coloring overrides on stdlib commands
      grep = "grep --color=auto";
      mkdir = "mkdir -p";
    };

    # Abbreviations expand inline as you type — `g<space>` becomes
    # `git `. You see the full command before running it, history
    # records the expanded form, and tab-completion works on the
    # expanded command. Preferred over aliases for any prefix-style
    # shortcut where the expansion is informative.
    shellAbbrs = {
      code = "codium";
    };

    # home.sessionVariables only writes hm-session-vars.sh (POSIX
    # syntax), which fish doesn't source. zsh sessions inherit it via
    # ~/.zshenv, so sshd's `/bin/zsh -c "fish ..."` works transparently.
    # But macOS GUI terminals (Ghostty's `login -fl aragao bash
    # --noprofile --norc -c "exec -l fish"`) launch fish without a zsh
    # wrapper, so we re-export the var in fish syntax here. Path must
    # match darwin/sops.nix's keyFile.
    shellInit = lib.mkIf isDarwin ''
      set -gx SOPS_AGE_KEY_FILE $HOME/.config/sops/age/keys.txt
    '';

    interactiveShellInit = ''
      # Any-nix-shell integration for better nix-shell experience
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source

      # Word navigation with Ctrl+Left/Right arrows
      bind \e\[1\;5C forward-word
      bind \e\[1\;5D backward-word
      bind \e\[C forward-word
      bind \e\[D backward-word

      # Use local k3s kubeconfig when no KUBECONFIG is set
      if test -r /etc/rancher/k3s/k3s.yaml; and not set -q KUBECONFIG
        set -gx KUBECONFIG /etc/rancher/k3s/k3s.yaml
      end

      # Puppeteer / Chrome DevTools MCP
      set -gx PUPPETEER_EXECUTABLE_PATH /etc/profiles/per-user/aragao/bin/brave
    '';

    functions = {
      sops-edit = {
        description = "Edit a sops file: sudo + host key on Linux, direct on macOS";
        body = ''
          # On macOS the personal age key lives at the default location
          # ~/.config/sops/age/keys.txt (see darwin/sops.nix), so sops
          # finds it without any wrapper magic.
          if test (uname) = Darwin
            command sops $argv
            return $status
          end

          # On NixOS the decryption key is the host key managed by
          # sops-nix at /var/lib/sops-nix/key.txt — root-readable only.
          # Override SOPS_AGE_KEY_FILE explicitly so sudo's env-reset
          # can't drop it.
          sudo -E env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops $argv
          set -l rc $status

          # Defensive: sops normally preserves ownership on rewrite,
          # but if a path argument ended up root-owned, hand it back.
          set -l my_uid (id -u)
          set -l my_grp (id -gn)
          for arg in $argv
            if test -e "$arg"
              set -l owner_uid (stat -c %u "$arg" 2>/dev/null)
              if test "$owner_uid" = 0
                sudo chown $my_uid:$my_grp "$arg"
              end
            end
          end
          return $rc
        '';
      };
    };
  };
}
