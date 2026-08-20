{ inputs, pkgs, ... }:

{
  imports = [ inputs.vicinae.homeManagerModules.default ];

  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    systemd.environment.QT_QUICK_DISABLE_ANIMATIONS = "1";
    settings = {
      theme.dark.name = "catppuccin-mocha";
      font.normal.size = 12;
      launcher_window.opacity = 1.0;
      close_on_focus_loss = true;
      pop_to_root_on_close = true;
    };
    extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
      # Extension names here: https://github.com/vicinaehq/extensions/tree/main/extensions
      nix
      power-profile
    ];
  };

  xdg.desktopEntries.vicinae-toggle = {
    name = "Vicinae Toggle";
    exec = "vicinae toggle";
    noDisplay = true;
    settings.StartupNotify = "false";
  };

  xdg.desktopEntries.vicinae-switch-windows = {
    name = "Vicinae Switch Windows";
    exec = "vicinae vicinae://launch/wm/switch-windows";
    noDisplay = true;
    settings.StartupNotify = "false";
  };
}
