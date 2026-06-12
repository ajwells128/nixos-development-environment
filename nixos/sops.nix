{
  config,
  pkgs,
  lib,
  owner,
  ...
}:

{
  # Install sops package system-wide
  environment.systemPackages = with pkgs; [ sops ];

  # sops-nix configuration
  sops = {
    # Default sops file location
    defaultSopsFile = ../secrets/secrets.yaml;

    # Validate sops files at build time
    validateSopsFiles = true; # Set to true once you have secrets file

    # Age key configuration
    age = {
      # Path to age key for decryption - use metadata owner name
      keyFile = "/var/lib/sops-nix/key.txt";
      # Generate host key automatically if it doesn't exist
      generateKey = true;
    };

    # Secret definitions
    secrets = {
      # User passwords
      "user_password" = {
        owner = "root";
        group = "root";
        mode = "0400";
        neededForUsers = true;
      };

      "root_password" = {
        owner = "root";
        group = "root";
        mode = "0400";
        neededForUsers = true;
      };

      "git_work_email" = {
        owner = owner.name;
        group = "users";
        mode = "0400";
      };

      # SSH keys for GitHub
      "ssh_key_github" = {
        owner = owner.name;
        group = "users";
        mode = "0400";
        path = "/home/${owner.name}/.ssh/id_ed25519";
      };

      "ssh_pubkey_github" = {
        owner = owner.name;
        group = "users";
        mode = "0400";
        path = "/home/${owner.name}/.ssh/id_ed25519.pub";
      };
    };
  };

  # Account passwords are sourced from sops-managed files. `neededForUsers
  # = true` on the corresponding secrets (see above) ensures sops-nix
  # decrypts them in an early activation step that runs before the `users`
  # step, so these paths are guaranteed to exist by the time NixOS creates
  # the accounts.
  #
  # Do NOT guard these with `builtins.pathExists` — that runs at Nix
  # evaluation time on the builder, where /run/secrets-for-users/ does not
  # exist yet, so the override silently falls back to `initialPassword`.
  # For genuine first-boot installs (host age key not yet provisioned),
  # handle bootstrap out-of-band (installer-set password, `passwd` on first
  # login, or a dedicated bootstrap flag).
  users.users.${owner.name}.hashedPasswordFile = config.sops.secrets.user_password.path;
  users.users.root.hashedPasswordFile = config.sops.secrets.root_password.path;

  # Ensure SSH directory exists with proper permissions
  system.activationScripts.sops-ssh-setup = lib.stringAfter [ "users" ] ''
    # Create .ssh directory for ${owner.name} if it doesn't exist
    mkdir -p /home/${owner.name}/.ssh
    chown ${owner.name}:users /home/${owner.name}/.ssh
    chmod 700 /home/${owner.name}/.ssh
  '';
}
