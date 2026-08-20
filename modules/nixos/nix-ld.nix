{ ... }:

{
  # Makes prebuilt binaries that hardcode /lib64/ld-linux-x86-64.so.2 as
  # their loader (uv/pip wheels, language servers, vendor SDKs) work on
  # NixOS.
  programs.nix-ld.enable = true;
}
