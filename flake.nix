{
  description = "g's cross-platform Nix config (NixOS + future Ubuntu/macOS via home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae.url = "github:vicinaehq/vicinae";

    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pia-desktop.url = "github:gplusplus314/pia-desktop.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }@inputs:
    let
      mkHome =
        {
          system,
          user,
          modules,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              (final: prev: {
                unstable = import nixpkgs-unstable {
                  inherit system;
                  config.allowUnfree = true;
                };
              })
            ];
          };
          extraSpecialArgs = {
            inherit inputs user;
            gnix = self;
          };
          modules = modules ++ [
            (
              { lib, pkgs, ... }:
              {
                nix.package = lib.mkDefault pkgs.nix;
              }
            )
          ];
        };

      # Username, home dir, and system come from the environment (needs
      # --impure), for remote boxes and devcontainers where they aren't known
      # in advance.
      mkPortable =
        profile:
        mkHome {
          system = builtins.currentSystem;
          user = builtins.getEnv "USER";
          modules = [
            profile
            {
              home.username = builtins.getEnv "USER";
              home.homeDirectory = builtins.getEnv "HOME";
            }
          ];
        };

      mkPreCommit =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        inputs.git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # Same tool `nix fmt` uses.
            treefmt = {
              enable = true;
              packageOverrides.treefmt = pkgs.nixfmt-tree;
            };

            # Scans staged file contents for key-shaped strings.
            ripsecrets.enable = true;

            flake-check = {
              enable = true;
              entry = "nix flake check --no-build";
              pass_filenames = false;
            };

            # This repo is public. Machine identity and secrets belong in a
            # private host repo; refuse paths that look like either. This just
            # reduces silly accidents; it's not foolproof.
            private-paths = {
              enable = true;
              name = "private paths";
              entry = builtins.toString (
                pkgs.writeShellScript "private-paths" ''
                  leaked=()
                  for file in "$@"; do
                    base="''${file##*/}"
                    case "$base" in
                      secrets.nix | .env | .env.* | *.key | *.pem | *.p12 | *.pfx | *.asc | id_rsa* | id_ecdsa* | id_ed25519*)
                        leaked+=("$file")
                        continue
                        ;;
                    esac
                    case "$file" in
                      hosts/* | secrets/* | */secrets/*)
                        leaked+=("$file")
                        ;;
                    esac
                  done
                  if ((''${#leaked[@]})); then
                    echo "these staged paths look machine-specific or secret:" >&2
                    printf '  %s\n' "''${leaked[@]}" >&2
                    echo "if a path is a false positive, commit with --no-verify" >&2
                    exit 1
                  fi
                ''
              );
            };
          };
        };

      mkDevShell =
        system:
        let
          pre-commit = mkPreCommit system;
        in
        nixpkgs.legacyPackages.${system}.mkShell {
          inherit (pre-commit) shellHook;
          buildInputs = pre-commit.enabledPackages;
        };
    in
    {
      formatter = {
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
        aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
      };

      # `nix develop` installs the pre-commit hooks.
      devShells = {
        x86_64-linux.default = mkDevShell "x86_64-linux";
        aarch64-darwin.default = mkDevShell "aarch64-darwin";
      };

      # Named role profiles for the private hosts repo to import without
      # knowing this repo's layout.
      nixosModules = {
        desktop = ./profiles/nixos/desktop.nix;
      };

      homeModules = {
        headless = ./profiles/home/headless.nix;
        darwin = ./profiles/home/darwin.nix;
        linux-desktop = ./profiles/home/linux-desktop.nix;
      };

      # Built by scripts/portable. Machine-specific entries should be in
      # private host repos, not here.
      #   portable               = headless CLI, any OS
      #   portable-darwin        = macOS with GUI apps
      #   portable-linux-desktop = Linux KDE Plasma desktop
      homeConfigurations = {
        portable = mkPortable ./profiles/home/headless.nix;
        portable-darwin = mkPortable ./profiles/home/darwin.nix;
        portable-linux-desktop = mkPortable ./profiles/home/linux-desktop.nix;
      };

      # Entry point for a private per-host flake, whose whole flake.nix is:
      #
      #   outputs = { gnix, ... }: gnix.lib.mkHost {
      #     hostName = "<hostname>";
      #     nixos = ./default.nix;
      #   };
      #
      # `nixos` (a NixOS module) should configure
      # nixosConfigurations.<hostname>.
      #
      # `home` ({ user, system, modules }, or standalone home-manager for
      # non-NixOS machines) should configure
      # homeConfigurations.<user>@<hostname>; its modules list may name this
      # flake's homeModules by string (e.g. "linux-desktop") alongside ordinary
      # modules. Host modules get this flake's `inputs` and the flake itself as
      # `gnix` via specialArgs.
      lib.mkHost =
        {
          hostName,
          nixos ? null,
          home ? null,
        }:
        let
          nixosConfigurations = nixpkgs.lib.optionalAttrs (nixos != null) {
            ${hostName} = nixpkgs.lib.nixosSystem {
              specialArgs = {
                inherit inputs;
                gnix = self;
              };
              modules = [
                { networking.hostName = nixpkgs.lib.mkDefault hostName; }
                nixos
              ];
            };
          };

          homeConfigurations = nixpkgs.lib.optionalAttrs (home != null) {
            "${home.user}@${hostName}" = mkHome {
              inherit (home) system user;
              modules = map (m: if builtins.isString m then self.homeModules.${m} else m) home.modules;
            };
          };

          # Refuse to build a host with gnix.debug.enable left on (see
          # modules/nixos/debug.nix). Forces the host's config.
          debugOn = nixos != null && nixosConfigurations.${hostName}.config.gnix.debug.enable;

          mkDebugCheck =
            system:
            if !debugOn then
              nixpkgs.legacyPackages.${system}.runCommand "gnix-debug-disabled" { } "touch $out"
            else
              throw "gnix.debug.enable is set on ${hostName}";
        in
        {
          inherit nixosConfigurations homeConfigurations;

          checks = {
            x86_64-linux.debug-disabled = mkDebugCheck "x86_64-linux";
            aarch64-darwin.debug-disabled = mkDebugCheck "aarch64-darwin";
          };

          inherit (self) formatter;
        };
    };
}
