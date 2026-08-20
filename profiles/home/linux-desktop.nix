{ pkgs, ... }:

{
  imports = [
    ./headless.nix
    ../../modules/home/firefox.nix
    ../../modules/home/kitty
    ../../modules/home/launcher.nix
    ../../modules/home/mime.nix
    ../../modules/home/plasma
  ];

  services.gpg-agent.pinentry.package = pkgs.pinentry-qt;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      IdentityAgent = "~/.1password/agent.sock";
      # Stops ssh from quietly falling back to on-disk ~/.ssh keys when the
      # 1Password agent socket is missing.
      IdentitiesOnly = true;
    };
  };

  home.packages = with pkgs; [
    audacity
    libreoffice-qt
  ];
}
