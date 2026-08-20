{ lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  xdg.configFile."kitty/resize_master.py".source = ./resize_master.py;
  xdg.configFile."kitty/copy_last_command.py".source = ./copy_last_command.py;

  programs.kitty = {
    enable = true;
    package = pkgs.unstable.kitty;

    font = {
      name = "JetBrainsMono Nerd Font Mono";
      package = pkgs.nerd-fonts.jetbrains-mono;
      size = if isDarwin then 16.0 else 13.0;
    };

    environment = {
      XDG_CONFIG_HOME = "$HOME/.config";
    };

    settings = {
      clear_all_shortcuts = "yes";
      shell_integration = "enabled";
      shell = "${pkgs.fish}/bin/fish";

      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty-{kitty_pid}";

      action_alias = "kitty_scrollback_nvim kitten ~/.local/share/nvim/lazy/kitty-scrollback.nvim/python/kitty_scrollback_nvim.py";

      disable_ligatures = "always";

      hide_window_decorations = "titlebar-only";

      background = "#1A1A1A";

      cursor_blink_interval = 0;
      enable_audio_bell = "no";

      momentum_scroll = 0.97;
      touch_scroll_multiplier = 1.0;
      pixel_scroll = "yes";

      active_border_color = "#00ff00";
      inactive_border_color = "#444444";
      draw_minimal_borders = "no";
      window_margin_width = 0;
      window_padding_width = 4;

      tab_bar_edge = "bottom";
      tab_bar_style = "separator";
      tab_bar_min_tabs = 1;
      tab_separator = " ┇ ";

      bell_on_tab = "yes";
      tab_title_template = "{index}: {title}";
      active_tab_foreground = "#000";
      active_tab_background = "#0C0";
      active_tab_font_style = "bold";
      inactive_tab_foreground = "#999";
      inactive_tab_background = "#222";
      inactive_tab_font_style = "normal";

      enabled_layouts = "tall";
    }
    // lib.optionalAttrs isDarwin {
      kitty_mod = "cmd+shift";
      macos_option_as_alt = "yes";
      macos_quit_when_last_window_closed = "yes";
    };

    keybindings = {
      "kitty_mod+c" = "copy_to_clipboard";
      "kitty_mod+v" = "paste_from_clipboard";

      "kitty_mod+up" = "scroll_line_up";
      "kitty_mod+down" = "scroll_line_down";
      "kitty_mod+page_up" = "scroll_page_up";
      "kitty_mod+page_down" = "scroll_page_down";
      "kitty_mod+o" = "scroll_to_prompt -1";
      "kitty_mod+i" = "scroll_to_prompt 1";
      "kitty_mod+h" = "kitty_scrollback_nvim";

      "kitty_mod+equal" = "change_font_size all +1.0";
      "kitty_mod+minus" = "change_font_size all -1.0";
      "kitty_mod+alt+0" = "change_font_size all 0";

      "kitty_mod+f" = "kitten hints --alphabet ntesiroahdmglpufywqcxz";
      "kitty_mod+s" = "kitten hints --type hyperlink --alphabet ntesiroahdmglpufywqcxz";

      "kitty_mod+y>c" = "kitten copy_last_command.py";
      "kitty_mod+y>p" = "kitten hints --type path --program @ --alphabet ntesiroahdmglpufywqcxz";
      "kitty_mod+y>h" = "kitten hints --type hash --program @ --alphabet ntesiroahdmglpufywqcxz";
      "kitty_mod+y>f" = "kitten hints --type url --program @ --alphabet ntesiroahdmglpufywqcxz";
      "kitty_mod+y>i" = "kitten hints --type ip --program @ --alphabet ntesiroahdmglpufywqcxz";

      "kitty_mod+t" = "new_tab";
      "kitty_mod+end" = "move_tab_forward";
      "kitty_mod+home" = "move_tab_backward";
      "kitty_mod+r" = "set_tab_title";
      "kitty_mod+1" = "goto_tab 1";
      "kitty_mod+2" = "goto_tab 2";
      "kitty_mod+3" = "goto_tab 3";
      "kitty_mod+4" = "goto_tab 4";
      "kitty_mod+5" = "goto_tab 5";
      "kitty_mod+6" = "goto_tab 6";
      "kitty_mod+7" = "goto_tab 7";
      "kitty_mod+8" = "goto_tab 8";
      "kitty_mod+9" = "goto_tab 9";
      "kitty_mod+0" = "goto_tab 10";
      "kitty_mod+q" = "close_tab";

      "kitty_mod+enter" = "new_window_with_cwd";
      "kitty_mod+w" = "close_window";
      "alt+down" = "next_window";
      "alt+up" = "previous_window";
      "shift+alt+down" = "move_window_forward";
      "shift+alt+up" = "move_window_backward";
      "alt+left" = "kitten resize_master.py shrink";
      "alt+right" = "kitten resize_master.py grow";
      "alt+shift+right" = "resize_window taller";
      "alt+shift+left" = "resize_window shorter";

      "shift+enter" = ''send_text all \e\r'';
    }
    // lib.optionalAttrs isDarwin {
      "cmd+@" = ''send_text all \x00'';
      "cmd+a" = ''send_text all \x01'';
      "cmd+b" = ''send_text all \x02'';
      "cmd+c" = ''send_text all \x03'';
      "cmd+d" = ''send_text all \x04'';
      "cmd+e" = ''send_text all \x05'';
      "cmd+f" = ''send_text all \x06'';
      "cmd+g" = ''send_text all \x07'';
      "cmd+h" = ''send_text all \x08'';
      "cmd+i" = ''send_text all \x09'';
      "cmd+j" = ''send_text all \x0A'';
      "cmd+k" = ''send_text all \x0B'';
      "cmd+l" = ''send_text all \x0C'';
      "cmd+m" = ''send_text all \x0D'';
      "cmd+n" = ''send_text all \x0E'';
      "cmd+o" = ''send_text all \x0F'';
      "cmd+p" = ''send_text all \x10'';
      "cmd+q" = ''send_text all \x11'';
      "cmd+r" = ''send_text all \x12'';
      "cmd+s" = ''send_text all \x13'';
      "cmd+t" = ''send_text all \x14'';
      "cmd+u" = ''send_text all \x15'';
      "cmd+v" = ''send_text all \x16'';
      "cmd+w" = ''send_text all \x17'';
      "cmd+x" = ''send_text all \x18'';
      "cmd+y" = ''send_text all \x19'';
      "cmd+z" = ''send_text all \x1A'';
      "cmd+[" = ''send_text all \x1B'';
      "cmd+\\" = ''send_text all \x1C'';
      "cmd+]" = ''send_text all \x1D'';
      "cmd+^" = ''send_text all \x1E'';
      "cmd+/" = ''send_text all \x1F'';

      "cmd+up" = ''send_text all \x1B[1;5A'';
      "cmd+down" = ''send_text all \x1B[1;5B'';
      "cmd+right" = ''send_text all \x1B[1;5C'';
      "cmd+left" = ''send_text all \x1B[1;5D'';
    };
  };
}
