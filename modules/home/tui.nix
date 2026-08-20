{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lazygit
    television
    btop
  ];
}
