# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

gnix is a **public** Nix flake of reusable dotfiles: Home Manager user
environments (Linux/KDE Plasma, macOS, headless CLI) plus NixOS role modules.
Machines are not defined here. Each machine has a **private** host flake that
consumes gnix as an input via `gnix.lib.mkHost`; it is cloned into `hosts/<name>`
(gitignored) and is what the machine actually rebuilds against. Never put
hostnames, disk UUIDs, hardware specifics, or secrets in this repo; they
belong in the private host repo.

## Commands

```sh
nix develop                      # once: installs the pre-commit hooks
nix fmt                          # format (nixfmt-tree via treefmt)
nix flake check --no-build       # evaluate all outputs (also a pre-commit hook)
scripts/portable                 # build + activate a portable home config from this checkout
nix build .#homeConfigurations.portable.activationPackage --impure   # build only
```

Portable configs read `$USER`, `$HOME`, and the current system from the
environment, so anything touching `homeConfigurations.portable*` needs
`--impure`.

To rebuild a real machine, work from its host checkout under `hosts/<name>`
(see that repo's README; typically `./apply`, which overrides the gnix input
with this surrounding checkout, tracked files only, dirty included).

Pre-commit hooks: treefmt, ripsecrets, `nix flake check --no-build`, and a
`private-paths` guard that rejects staged paths under `hosts/`, `secrets/`, or
key/env-looking filenames.

## Architecture

- `flake.nix` is the whole public API:
  - `homeModules` (`headless`, `darwin`, `linux-desktop`) and `nixosModules`
    (`desktop`) expose the role profiles in `profiles/` by name, so host flakes
    don't depend on this repo's layout.
  - `homeConfigurations.portable{,-darwin,-linux-desktop}` are built by
    `scripts/portable` (also runnable via `curl | bash` from GitHub).
  - `lib.mkHost { hostName, nixos?, home?, inputs? }` produces a host flake's
    `nixosConfigurations.<host>`, `homeConfigurations."<user>@<host>"`,
    `checks`, and `formatter`. Host `inputs` are merged over gnix's, so
    host-only inputs (e.g. `nixos-hardware`) are declared and locked in the
    host flake. `home.modules` may name gnix `homeModules` by string.
  - All modules receive `inputs` (merged) and `gnix` (this flake) via
    specialArgs; home modules also receive `user`.
  - `pkgs.unstable` is an overlay for nixpkgs-unstable packages in home
    configs; the base is the pinned stable release.
- `profiles/` compose `modules/`: `profiles/home/headless.nix` is the base that
  `darwin` and `linux-desktop` import; `profiles/nixos/desktop.nix` is the
  NixOS role. Profiles set defaults with `lib.mkDefault` where hosts are
  expected to override (e.g. kernel).
- `modules/nixos/debug.nix` defines `gnix.debug.enable`; `mkHost` emits a
  `checks.*.debug-disabled` that throws if a host leaves it on.
- `modules/home/plasma/` builds custom KDE pieces from source inside Nix: a C++
  KWin effect (`kwin/effect`, CMake), a KWin script, and a QML plasmoid whose
  `@accent@` placeholder is substituted from the single `accent` color in
  `default.nix`.
- `modules/home/vim/nvim/` is a LazyVim config (via `lazyvim-nix`) in Lua.

`OUT_OF_BAND_CONFIG.md` lists manual setup Nix can't do (1Password CLI
integration and SSH agent, which `linux-desktop` SSH config depends on).

## Style

`.editorconfig`: 2-space indent for Nix and Lua. Run `nix fmt` before
committing.
