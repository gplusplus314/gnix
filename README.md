# gnix - Gerry's Nixified Dotfiles

Cross-platform dotfiles for NixOS, Linux, and macOS via Nix + Home Manager. This
replaces [gdot](https://github.com/gplusplus314/gdot), hence the name `gnix`. It
pairs well with [`gkey`](https://github.com/gplusplus314/gkey), my custom
keyboard.

This repo is the public and reusable components of my dotfiles. It holds the
main flake that defines my user environment and the provides `lib.mkHost`, the entry point
for host/machine-specific flakes. Machine identity (hostnames, disk UUIDs,
hardware quirks) are in in private, per-host flakes that pull this repo in as an
input and are what machines actually rebuild against.

## Portable (remote machines / devcontainers)

Applies the dotfiles on any box Nix runs on, even one whose username and
hostname aren't known ahead of time (the config reads username, home dir, and
system from the environment). One command on a fresh box installs Nix if
missing, then builds and activates:

```sh
curl -fsSL https://raw.githubusercontent.com/gplusplus314/gnix/main/scripts/portable | bash
```

Without a terminal (CI, unattended pipe, etc), it installs the headless CLI-only
config. Interactively, it asks about installing GUI apps, defaulting to no. From
a local clone, `scripts/portable` uses the checkout instead of GitHub.

## Pre-commit hooks

Hooks are declared in `flake.nix` via
[git-hooks.nix](https://github.com/cachix/git-hooks.nix) and installed by
running `nix develop` once. The hooks provide sanity checks and formatting.
