{
  pkgs,
  inputs,
  user,
  ...
}:

{
  imports = [
    ../../modules/nixos/base.nix
    ../../modules/nixos/debug.nix
    ../../modules/nixos/musescore.nix
    ../../modules/nixos/nix-ld.nix
    ../../modules/nixos/plasma.nix
    inputs.pia-desktop.nixosModules.pia-desktop
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = false;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  networking.networkmanager.enable = true;

  users.users.${user} = {
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    isNormalUser = true;
    initialPassword = "changeme";
  };

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ user ];
  };

  services.pia-desktop = {
    enable = true;
    users = [ user ];
  };

  environment.systemPackages = with pkgs; [
    brave
    neovim
    lshw
  ];

  services.printing = {
    enable = true;
    drivers = [ pkgs.brlaser ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
  };
  security.rtkit.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
