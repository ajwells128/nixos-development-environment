{ pkgs, lib, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  # Shell configuration
  programs.zsh = {
    enable = true;

    # Kitty (and Ghostty) forward their native TERM over SSH. Remote hosts
    # often lack that terminfo — set-environment/tput fail and zsh line
    # editing duplicates characters. .zshenv runs before profile.d hooks.
    envExtra = ''
      if [[ -n "''${SSH_CONNECTION:-}" ]]; then
        case "''${TERM:-}" in
          xterm-kitty|xterm-ghostty|ghostty) export TERM=xterm-256color ;;
        esac
      fi
    '';

    # On Darwin, Homebrew installs to /opt/homebrew (Apple Silicon) and
    # exposes its tools via `brew shellenv`. This is the declarative
    # replacement for the imperative two-line block brew prints at the
    # end of its installer:
    #
    #   echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> ~/.zprofile
    #
    # profileExtra is written to ~/.zprofile by home-manager.
    profileExtra = lib.mkIf isDarwin ''
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    '';
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
      styles = {
        alias = "fg=#89b4fa";
        builtin = "fg=#89b4fa";
        command = "fg=#89b4fa";
        comment = "fg=#6c7086";
        function = "fg=#89b4fa";
        path = "fg=#a6e3a1,underline";
        precommand = "fg=#cba6f7";
        single-hyphen-option = "fg=#f9e2af";
        double-hyphen-option = "fg=#f9e2af";
        single-quoted-argument = "fg=#a6e3a1";
        double-quoted-argument = "fg=#a6e3a1";
        unknown-token = "fg=#f38ba8";
      };
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "docker"
        "kubectl"
      ];
      theme = "robbyrussell";
    };

    shellAliases = {
      code = "codium";
    };

    initContent = ''
      # Word navigation with Ctrl+Left/Right arrows
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word
      bindkey '^[[OC' forward-word
      bindkey '^[[OD' backward-word

      export GOPATH="$HOME/go"
      export GOBIN="$GOPATH/bin"
      export PATH="$GOBIN:$PATH"

      # Some persisted shells can inherit tracing flags from prior sessions.
      # Clear them during init so command execution does not echo aliases/functions.
      unsetopt xtrace verbose 2>/dev/null || true

      # Edit a sops file. On macOS the personal age key sits at the
      # default ~/.config/sops/age/keys.txt (see darwin/sops.nix) so
      # plain sops works. On NixOS the decryption key is the host
      # key at /var/lib/sops-nix/key.txt (root-only), so we sudo into
      # it explicitly and restore ownership defensively afterwards.
      sops-edit() {
        if [[ "$(uname)" == "Darwin" ]]; then
          command sops "$@"
          return
        fi
        sudo -E env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops "$@"
        local rc=$?
        local arg
        for arg in "$@"; do
          if [[ -e "$arg" && "$(stat -c %u "$arg" 2>/dev/null)" == "0" ]]; then
            sudo chown "$(id -u):$(id -gn)" "$arg"
          fi
        done
        return $rc
      }
    '';
  };
}
