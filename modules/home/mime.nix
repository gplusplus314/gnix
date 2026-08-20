{ ... }:

{
  # Several modules contribute to mimeapps.list, so this module owns it and
  # they only add entries.
  xdg.mimeApps.enable = true;

  # Handler registration through xdg-mime/GIO rewrites this file in place
  # (write-temp + rename), turning home-manager's symlink into a regular
  # file. The next activation then refuses to clobber it and the rebuild
  # fails, hence force. Same deal for the deprecated data-dir copy.
  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;
}
