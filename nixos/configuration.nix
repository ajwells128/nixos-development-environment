# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    ./users.nix
    ./ssh.nix
    ./virtualization.nix
    ./security.nix
    ./packages.nix
    ./desktop.nix
    ./sops.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
    };
    # Opinionated: disable channels
    channel.enable = false;
  };

  # TODO: Set your hostname
  networking.hostName = "vmware-work";
  networking = {
    useDHCP = false;
    # TODO: Verify this works for your setup. Consider commenting out the entire networking block
    # initially to see what your host sets via dhcp. This is what my macos did for VMWare Fusion
    interfaces.enp2s0 = {
      ipv4.addresses = [{
        address = "172.16.126.128";
        prefixLength = 24;
      }];
    };
    defaultGateway = "172.16.126.2";
    nameservers = [ "1.1.1.1" ];
    hosts = {
      "172.16.126.128" = [
        "infinity.local"
        "portal.infinity.local"
      ];
    };
  };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };

  # Corporate internal CAs + the MITM TLS-intercepting proxy root.
  # Required for curl/git/openssl to validate connections that go
  # through the corporate egress proxy or hit internal services.
  security.pki.certificateFiles = [
    ../certs/internal-root-2.pem
    ../certs/internal-root-1.pem
    ../certs/internal-intermediate.pem
    ../certs/proxy-root.pem
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
