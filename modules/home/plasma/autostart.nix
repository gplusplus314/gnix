{ ... }:

let
  apps = [
    # name is ~/.config/autostart/{name}.desktop
    {
      name = "1password";
      # --silent = systray only
      exec = "1password --silent";
      desktop = null;
    }
    {
      name = "pia";
      # --quiet = systray only
      exec = "pia-client --quiet";
      desktop = null;
    }
    {
      name = "kitty";
      exec = "kitty";
      class = "kitty";
      desktop = 1;
    }
    {
      name = "firefox";
      exec = "firefox";
      class = "firefox";
      desktop = 10;
    }
  ];

  placed = builtins.filter (app: app.desktop != null) apps;

  autostartEntry = app: {
    name = "autostart/${app.name}.desktop";
    value.text = ''
      [Desktop Entry]
      Type=Application
      Name=${app.name}
      Exec=${app.exec}
      Terminal=false
    '';
  };

  desktopRule = app: {
    description = "${app.name} on desktop ${toString app.desktop}";
    # Match by substring because KWin's wmclass is the Wayland app id, and
    # for some apps that's "<resource> <class>" instead of the bare binary
    # name.
    match.window-class = {
      value = app.class;
      type = "substring";
      match-whole = false;
    };
    # "initially" only places the window when it first appears, so dragging
    # it to another desktop later still sticks. Krohnkite tiles per-desktop
    # and picks the window up wherever KWin puts it.
    apply.desktops = {
      value = "Desktop_${toString app.desktop}";
      apply = "initially";
    };
  };
in
{
  xdg.configFile = builtins.listToAttrs (map autostartEntry apps);

  programs.plasma.window-rules = map desktopRule placed;
}
