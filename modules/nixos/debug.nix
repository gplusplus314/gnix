{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.gnix.debug;
in
{
  # Enable only for debugging! This keeps up to 20G of core dumps under /var.
  options.gnix.debug.enable = lib.mkEnableOption "diagnostics for tracking down crashes: full coredump retention, debug-info outputs, a local debuginfod, gdb on PATH, and KWin debug logging routed to the journal";

  config = lib.mkIf cfg.enable {
    systemd.coredump.enable = true;
    systemd.coredump.extraConfig = ''
      ProcessSizeMax=8G
      ExternalSizeMax=8G
      MaxUse=20G
      MaxFileSize=8G
    '';

    environment.enableDebugInfo = true;

    services.nixseparatedebuginfod2.enable = true;

    environment.systemPackages = with pkgs; [ gdb ];

    environment.sessionVariables.QT_LOGGING_RULES = "kwin_*.debug=true";
  };
}
