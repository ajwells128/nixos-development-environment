{
  config,
  lib,
  owner,
  ...
}:

let
  # Path the work-scope `includeIf` points at. Written by the
  # `gitWorkInclude` home.activation below from the sops-managed
  # email at /run/secrets/git_work_email. We deliberately do NOT use
  # `programs.git.includes[].contents` for the work scope (it would
  # bake the email into the Nix store — the exact leak this commit
  # is fixing).
  globalConfig = "${config.home.homeDirectory}/.gitconfig";
  workEmailSecret = "/run/secrets/git_work_email";
in

{
  programs = {
    # TODO: Make this your own preference
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        dark = true;
        line-numbers = true;
        navigate = true;
        side-by-side = true;
        syntax-theme = "base16";

        file-style = "bold #cba6f7";
        hunk-header-file-style = "bold #89b4fa";
        hunk-header-line-number-style = "#f9e2af";
        line-numbers-left-style = "#6c7086";
        line-numbers-right-style = "#6c7086";
        line-numbers-minus-style = "#f38ba8";
        line-numbers-plus-style = "#a6e3a1";
        minus-emph-style = "syntax #45475a";
        minus-style = "syntax #313244";
        plus-emph-style = "syntax #45475a";
        plus-style = "syntax #313244";
      };
    };

    git = {
      enable = true;

      settings = {
        init.defaultBranch = "main";
        pull.rebase = false;
        push.autoSetupRemote = true;

        # TODO: Make these your own preferences
        alias = {
          st = "status";
          co = "checkout";
          br = "branch";
          ci = "commit";
          commitane = "commit --amend --no-edit";
          unstage = "reset HEAD --";
          last = "log -1 HEAD";
          visual = "!gitk";
        };
      };
    };
  };

  # Render ~/.config/git/global.gitconfig from the sops-managed work
  # email. The name is constant.
  # Only the email comes from sops.
  home.activation.gitWorkInclude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="${globalConfig}"
    mkdir -p "$(dirname "$target")"

    if [[ -f "${workEmailSecret}" ]]; then
      email="$(cat "${workEmailSecret}")"
      if [[ -n "$email" && "$email" != "placeholder" ]]; then
        cat > "$target.tmp" <<EOF
    [user]
    	name = ${owner.fullName}
    	email = $email
    EOF
        mv "$target.tmp" "$target"
        chmod 0600 "$target"
      else
        # Secret present but empty / placeholder — wipe any stale
        # rendering rather than leave a half-baked file in place.
        rm -f "$target"
      fi
    else
      # Sops hasn't deployed the secret yet (first install, age key
      # not provisioned, etc.). Leave no work.gitconfig at all so
      # the includeIf is a clean no-op.
      rm -f "$target"
    fi
  '';
}
