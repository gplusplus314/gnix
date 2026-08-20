{ pkgs, ... }:

{
  environment.systemPackages = with pkgs.unstable; [
    musescore
    muse-sounds-manager
  ];
}
