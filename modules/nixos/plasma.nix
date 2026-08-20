{ pkgs, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = true;

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa
    krunner
    milou
    akonadi
    akonadi-calendar
    akonadi-mime
    akonadi-search
    akonadi-contacts
    kdepim-runtime
    kmailtransport
    libkdepim
    konsole
    kate
    discover
    khelpcenter
  ];
}
