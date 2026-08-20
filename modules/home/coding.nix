{ pkgs, ... }:

{
  nix.settings.pure-eval = false;

  home.packages = with pkgs; [
    go
    gopls

    cargo
    rustc
    rustfmt
    clippy
    rust-analyzer

    uv

    nixd
  ];
}
