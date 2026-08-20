{ ... }:

{
  imports = [
    ../../modules/home/cli.nix
    ../../modules/home/coding.nix
    ../../modules/home/tui.nix
    ../../modules/home/vim
  ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
