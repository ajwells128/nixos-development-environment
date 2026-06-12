# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  lib,
  pkgs,
  owner,
  ...
}:

{
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    ./google-chrome.nix
    ./development.nix
    ./vscode.nix
    ./fish.nix
    ./zsh.nix
    ./git.nix
    ./cursor.nix

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  # `nixpkgs.*` options belong in NixOS (`nixos/configuration.nix`) when
  # `home-manager.useGlobalPkgs` is enabled in the flake.`

  home = {
    username = owner.name;
    homeDirectory = "/home/${owner.name}";
  };

  # Add stuff for your user as you see fit:
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git.enable = true;

  # TODO: Make this your own preference
  # I prefer for alt tab to be switch windows rather than switch applications
  dconf.settings = {
    "org/gnome/desktop/wm/keybindings" = {
      switch-applications = lib.hm.gvariant.mkArray lib.hm.gvariant.type.string [];
      switch-applications-backward = lib.hm.gvariant.mkArray lib.hm.gvariant.type.string [];
      switch-windows = [ "<Super>Tab" "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Super>Tab" "<Alt><Shift>Tab" ];
    };
  };

  home.packages =
    with pkgs;
    [
      azure-cli
      awscli2
      databricks-cli
      google-cloud-sdk
      kubectl
      kubernetes-helm
      kubectx
      k9s
      stern
      ansible
      code2prompt

      taler-sync
      openssh
      mosh
      tmux
      screen
      htop
      nmap
      tcpdump
      socat
      netcat
      dig
      whois

      imagemagick
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
