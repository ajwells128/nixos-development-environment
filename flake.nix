{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
      # TODO: Update to your user name
      getUserName = _: "andrew";

      # Set special args for each machine
      setSpecialArgs = _ : {
        # TODO: Update all these details
        hostName = "vmware-work";
        owner = {
          name = "andrew";
          fullName = "Andrew Wells";
        };
        inherit inputs;
      };

      # Set Home Manager template (works for both NixOS and nix-darwin
      # since both expose `home-manager = { useUserPackages, useGlobalPkgs,
      # ... }` once the corresponding HM module is imported).
      setHomeManagerTemplate = _: {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          extraSpecialArgs = setSpecialArgs null;
          users.${getUserName null} = import ./home-manager;
          backupFileExtension = "hm-backup";
        };
      };
  in {
    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      # TODO replace with your chosen hostname
      vmware-work = nixpkgs.lib.nixosSystem {
        specialArgs = setSpecialArgs null;
        # > Our main nixos configuration file <
        modules = [
          # main system config
          ./nixos/configuration.nix

          # Prebuilt nix-index database for command-not-found lookup.
          inputs.nix-index-database.nixosModules.nix-index
          # Secrets management
          inputs.sops-nix.nixosModules.sops
          # Home Manager configuration. The template could probably be inlined
          home-manager.nixosModules.home-manager
          (setHomeManagerTemplate null)
        ];
      };
    };
  };
}
