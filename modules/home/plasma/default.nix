{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # The gnix accent purple. Templated into the plasmoid QML below and used
  # for the effect override colors.
  accent = "#AA00FF";

  krohnkite = pkgs.kdePackages.krohnkite;

  gnixEffects = pkgs.stdenv.mkDerivation {
    pname = "gnix-effects";
    version = "1.0";
    src = ./kwin/effect;
    nativeBuildInputs = with pkgs; [
      cmake
      kdePackages.extra-cmake-modules
      qt6.qtbase
    ];
    buildInputs = with pkgs; [
      kdePackages.kwin.dev
      kdePackages.kcoreaddons.dev
      kdePackages.kdecoration.dev
      qt6.qtbase
    ];
    dontWrapQtApps = true;
  };

  # Template the plasmoid so the accent color is only defined once (above).
  virtualDesktopIndicator = pkgs.runCommand "gnix-virtualdesktopindicator" { } ''
    cp -r ${./plasmoid/virtual-desktop-indicator} $out
    chmod -R u+w $out
    substituteInPlace $out/contents/ui/main.qml --replace-fail "@accent@" "${accent}"
  '';
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ./autostart.nix
  ];

  programs.plasma.enable = true;

  home.packages = [
    krohnkite
    gnixEffects
    pkgs.kdePackages.qttools
  ];

  xdg.configFile."gnix/kwin_effects.json".source =
    (pkgs.formats.json { }).generate "kwin_effects.json"
      {
        defaults = {
          width = 1;
          radius = 6;
          inset = 0;
          color = "0,200,0";
        };
        # `match` may combine windowClass, windowCaption, windowType. Every
        # populated field has to match (case-insensitive) and the first
        # matching entry wins.
        # windowType is one of the EffectWindow type flags (normal, dialog,
        # popup, popupMenu, dropdownMenu, comboBox, tooltip, splash, utility,
        # notification, criticalNotification, onScreenDisplay, dock, desktop,
        # menu, toolbar, dndIcon) or layerShell for wlr-layer-shell surfaces.
        overrides = [
          {
            match = {
              windowClass = "vicinae-server";
              windowType = "layerShell";
            };
            inset = 2;
            insetRight = 1;
            insetBottom = 1;
            radius = 8;
            width = 1;
            color = accent;
            warp = "topRight";
          }
          {
            match = {
              windowClass = "vicinae-server";
              windowCaption = "Vicinae Settings";
            };
            inset = 2;
            width = 2;
            radius = 8;
            color = accent;
          }
        ];
      };

  xdg.dataFile."kwin/scripts/gnix/metadata.json".source = ./kwin/script/metadata.json;
  xdg.dataFile."kwin/scripts/gnix/contents/ui/main.qml".source = ./kwin/script/contents/ui/main.qml;

  # Symlink the whole directory. KPackage resolves the package path via
  # metadata.json's canonical location, so per-file symlinks would point it at
  # a store path missing the rest of contents/ and the package fails to load.
  xdg.dataFile."plasma/plasmoids/gnix.virtualdesktopindicator".source = virtualDesktopIndicator;

  programs.plasma.workspace.colorScheme = "BreezeDark";

  programs.plasma.input.keyboard = {
    repeatDelay = 250;
    repeatRate = 40;
  };

  programs.plasma.kwin.virtualDesktops = {
    number = 10;
    rows = 1;
  };

  programs.plasma.configFile = {
    kwinrc = {
      "Script-krohnkite" = {
        screenGapLeft = 1;
        screenGapRight = 1;
        screenGapTop = 1;
        screenGapBottom = 2;
        screenGapBetween = 8;
        soleWindowNoGaps = true;
        directionalKeyDwm = true;
      };
      Plugins = {
        krohnkiteEnabled = true;
        gnixEnabled = true;
        "gnix-effectsEnabled" = true;
        slideEnabled = false;
        scaleEnabled = false;
        overviewEnabled = false;
        squashEnabled = false;
        tileseditorEnabled = false;
      };
      # Disables the hot-corner "overview" feature
      "Effect-overview".BorderActivate = "";
    };

    baloofilerc.General.folders = "${config.home.homeDirectory}/Documents,${config.home.homeDirectory}/Downloads";

    # Plasma-manager's [] writes just "none" which KDE ignores when the
    # registered default is non-empty. Writing the full tuple frees the key
    # persistently.
    kglobalshortcutsrc.kwin = {
      KrohnkiteSetMaster = "none,none,Krohnkite: Set master";
      KrohnkiteIncrease = "Meta+Shift+Right,none,Krohnkite: Increase";
      KrohnkiteDecrease = "Meta+Shift+Left,none,Krohnkite: Decrease";
      KrohnkitegrowWidth = "Meta+Right,none,Krohnkite: Grow Width";
      KrohnkiteShrinkWidth = "Meta+Left,none,Krohnkite: Shrink Width";
      KrohnkiteFocusNext = "Meta+Down,none,Krohnkite: Focus Next";
      KrohnkiteFocusPrev = "Meta+Up,none,Krohnkite: Focus Previous";
      KrohnkiteShiftDown = "Meta+Shift+Down,none,Krohnkite: Shift Down";
      KrohnkiteShiftUp = "Meta+Shift+Up,none,Krohnkite: Shift Up";
    };

    kdeglobals.General = {
      TerminalApplication = "kitty";
      TerminalService = "kitty.desktop";
    };
  };

  xdg.desktopEntries.kitty = {
    name = "Kitty";
    exec = "kitty";
    icon = "kitty";
    comment = "Fast, feature-rich, GPU based terminal emulator";
    terminal = false;
    categories = [
      "System"
      "TerminalEmulator"
    ];
  };

  programs.plasma.panels = [
    {
      location = "top";
      height = 24;
      widgets = [
        { panelSpacer.expanding = true; }
        "gnix.virtualdesktopindicator"
        { panelSpacer.expanding = true; }
        "org.kde.plasma.marginsseparator"
        "org.kde.plasma.systemtray"
        {
          digitalClock = {
            date.enable = false;
            time.format = "12h";
          };
        }
      ];
    }
    {
      location = "bottom";
      height = 56;
      floating = true;
      hiding = "autohide";
      lengthMode = "fit";
      alignment = "center";
      widgets = [
        {
          name = "org.kde.plasma.icontasks";
          config.General.showOnlyCurrentDesktop = false;
        }
      ];
    }
  ];

  programs.plasma.shortcuts = {
    # Keyboard layout switcher
    "KDE Keyboard Layout Switcher"."Switch to Last-Used Keyboard Layout" = [ ];
    "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = [ ];

    # Accessibility
    "kaccess"."Toggle Screen Reader On and Off" = [ ];

    # KWin script: move-and-follow (Meta+Shift+N produces Meta+<shifted-N>
    # after Shift is consumed). These bindings are the real ones. The
    # script's ShortcutHandlers register the actions unbound.
    "kwin"."move-to-desktop-1" = "Meta+!";
    "kwin"."move-to-desktop-2" = "Meta+@";
    "kwin"."move-to-desktop-3" = "Meta+#";
    "kwin"."move-to-desktop-4" = "Meta+$";
    "kwin"."move-to-desktop-5" = "Meta+%";
    "kwin"."move-to-desktop-6" = "Meta+^";
    "kwin"."move-to-desktop-7" = "Meta+&";
    "kwin"."move-to-desktop-8" = "Meta+*";
    "kwin"."move-to-desktop-9" = "Meta+(";
    "kwin"."move-to-desktop-10" = "Meta+)";

    # KWin: changed bindings
    "kwin"."Kill Window" = "Meta+Shift+Q"; # was Meta+Ctrl+Esc
    "kwin"."Window Close" = "Ctrl+Q"; # was Alt+F4

    # KWin: disabled defaults
    "kwin"."Edit Tiles" = [ ];
    "kwin"."Expose" = [ ];
    "kwin"."ExposeAll" = [ ];
    "kwin"."ExposeClass" = [ ];
    "kwin"."Grid View" = [ ];
    "kwin"."MoveMouseToCenter" = [ ];
    "kwin"."MoveMouseToFocus" = [ ];
    "kwin"."Overview" = [ ];
    "kwin"."Show Desktop" = [ ];
    "kwin"."Switch One Desktop Down" = [ ];
    "kwin"."Switch One Desktop Up" = [ ];
    "kwin"."Switch One Desktop to the Left" = [ ];
    "kwin"."Switch One Desktop to the Right" = [ ];
    "kwin"."Switch Window Down" = [ ];
    "kwin"."Switch Window Left" = [ ];
    "kwin"."Switch Window Right" = [ ];
    "kwin"."Switch Window Up" = [ ];
    "kwin"."Switch to Desktop 1" = "Meta+1";
    "kwin"."Switch to Desktop 2" = "Meta+2";
    "kwin"."Switch to Desktop 3" = "Meta+3";
    "kwin"."Switch to Desktop 4" = "Meta+4";
    "kwin"."Switch to Desktop 5" = "Meta+5";
    "kwin"."Switch to Desktop 6" = "Meta+6";
    "kwin"."Switch to Desktop 7" = "Meta+7";
    "kwin"."Switch to Desktop 8" = "Meta+8";
    "kwin"."Switch to Desktop 9" = "Meta+9";
    "kwin"."Switch to Desktop 10" = "Meta+0";
    "kwin"."Walk Through Windows" = [ ];
    "kwin"."Walk Through Windows (Reverse)" = [ ];
    "kwin"."Walk Through Windows of Current Application" = [ ];
    "kwin"."Walk Through Windows of Current Application (Reverse)" = [ ];
    "kwin"."Window Maximize" = [ ];
    "kwin"."Window Minimize" = [ ];
    "kwin"."Window One Desktop Down" = [ ];
    "kwin"."Window One Desktop Up" = [ ];
    "kwin"."Window One Desktop to the Left" = [ ];
    "kwin"."Window One Desktop to the Right" = [ ];
    "kwin"."Window Operations Menu" = [ ];
    "kwin"."Window Quick Tile Bottom" = [ ];
    "kwin"."Window Quick Tile Left" = [ ];
    "kwin"."Window Quick Tile Right" = [ ];
    "kwin"."Window Quick Tile Top" = [ ];
    "kwin"."Window to Next Screen" = [ ];
    "kwin"."Window to Previous Screen" = [ ];
    "kwin"."disableInputCapture" = [ ];
    "kwin"."view_actual_size" = [ ];

    # Power management: removed Meta+B, kept hardware Battery key
    "org_kde_powerdevil"."powerProfile" = "Battery";

    # Vicinae launcher
    "services/vicinae-toggle.desktop"."_launch" = "Meta+Space";
    "services/vicinae-switch-windows.desktop"."_launch" = "Meta+Tab";

    # Plasmashell: changed bindings
    "plasmashell"."activate application launcher" = [ ]; # was Meta / Alt+F1

    # Plasmashell: disabled defaults
    "plasmashell"."activate task manager entry 1" = [ ];
    "plasmashell"."activate task manager entry 2" = [ ];
    "plasmashell"."activate task manager entry 3" = [ ];
    "plasmashell"."activate task manager entry 4" = [ ];
    "plasmashell"."activate task manager entry 5" = [ ];
    "plasmashell"."activate task manager entry 6" = [ ];
    "plasmashell"."activate task manager entry 7" = [ ];
    "plasmashell"."activate task manager entry 8" = [ ];
    "plasmashell"."activate task manager entry 9" = [ ];
    "plasmashell"."clipboard_action" = [ ];
    "plasmashell"."cycle-panels" = [ ];
    "plasmashell"."manage activities" = [ ];
    "plasmashell"."show dashboard" = [ ];
    "plasmashell"."show-on-mouse-pos" = [ ];

    # Spectacle: region screenshot rebound, rest disabled
    "services/org.kde.spectacle.desktop"."RectangularRegionScreenShot" = "Meta+S";
    "services/org.kde.spectacle.desktop"."ActiveWindowScreenShot" = [ ];
    "services/org.kde.spectacle.desktop"."FullScreenScreenShot" = [ ];
    "services/org.kde.spectacle.desktop"."RecordRegion" = [ ];
    "services/org.kde.spectacle.desktop"."RecordScreen" = [ ];
    "services/org.kde.spectacle.desktop"."RecordWindow" = [ ];
    "services/org.kde.spectacle.desktop"."WindowUnderCursorScreenShot" = [ ];
    "services/org.kde.spectacle.desktop"."_launch" = [ ];

    # Terminal
    "services/kitty.desktop"."_launch" = "Meta+Return";

    # App launcher shortcuts: all disabled
    "services/org.kde.dolphin.desktop"."_launch" = [ ];
    "services/org.kde.konsole.desktop"."_launch" = [ ];
    "services/org.kde.krunner.desktop"."RunClipboard" = [ ];
    "services/org.kde.krunner.desktop"."_launch" = [ ];
    "services/org.kde.kscreen.desktop"."ShowOSD" = [ ];
    "services/systemsettings.desktop"."_launch" = [ ];
  };
}
