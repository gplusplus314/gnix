{ pkgs, ... }:

{
  imports = [
    ./headless.nix
    ../../modules/home/kitty
  ];

  home.packages = [ pkgs.pinentry_mac ];
}
