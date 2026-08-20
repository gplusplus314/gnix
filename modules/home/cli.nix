{ lib, pkgs, ... }:

{
  home.sessionVariables.SHELL = "${pkgs.fish}/bin/fish";

  programs.fish = {
    enable = true;
    functions.fish_greeting = "";
    # Wrap `nix shell`/`nix develop` to drop into fish (not bash) and export
    # IN_NIX_SHELL so the prompt's nix-shell indicator shows up.
    functions.nix = {
      wraps = "nix";
      body = ''
        if test (count $argv) -ge 1
          switch $argv[1]
            case shell develop
              if not contains -- --command $argv
                set -l mode impure
                if contains -- --ignore-environment $argv; or contains -- -i $argv
                  set mode pure
                end
                command nix $argv --command env IN_NIX_SHELL=$mode $SHELL
                return
              end
          end
        end
        command nix $argv
      '';
    };
    functions.gclone = {
      description = "git clone into ~/src/<host>/<path> and cd there";
      body = ''
        if test (count $argv) -ne 1
          echo "usage: gclone <git-url>" >&2
          return 2
        end
        set -l url $argv[1]
        set -l host
        set -l path

        set -l m (string match -r '^[a-zA-Z][a-zA-Z0-9+.-]*://(?:[^@/]+@)?([^/:]+)(?::[0-9]+)?/(.+)$' -- $url)
        if test (count $m) -eq 3
          set host $m[2]
          set path $m[3]
        else
          set m (string match -r '^[^@:/]+@([^:/]+):(.+)$' -- $url)
          if test (count $m) -eq 3
            set host $m[2]
            set path $m[3]
          else
            echo "gclone: cannot parse URL: $url" >&2
            return 2
          end
        end

        set path (string replace -r '\.git$' "" -- $path)

        set -l target $HOME/src/$host/$path
        if test -e $target
          echo "gclone: target already exists: $target" >&2
          return 1
        end

        set -l created
        set -l probe (dirname $target)
        while not test -d $probe
          set created $created $probe
          set probe (dirname $probe)
        end

        mkdir -p (dirname $target); or return 1

        if git clone $url $target
          cd $target
        else
          set -l rc $status
          rm -rf $target
          for d in $created
            rmdir $d 2>/dev/null
          end
          return $rc
        end
      '';
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings.nix_shell.format = "via [$symbol]($style) ";
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      init.defaultBranch = "main";
    };
  };

  programs.gh.enable = true;

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      inline_height = 10;
      filter_mode = "directory";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.bat.enable = true;

  programs.fd.enable = true;

  programs.fzf.enable = true;
  # Load fzf before Atuin (conf.d file sorted ahead of atuin.fish) so Atuin's
  # Ctrl+R binding wins whether Atuin loads via conf.d or
  # interactiveShellInit.
  xdg.configFile."fish/conf.d/00-fzf.fish".text = ''
    fzf --fish | source
    bind --erase \cr
    bind -M insert --erase \cr
  '';

  home.packages =
    with pkgs;
    [
      ffmpeg
      figlet
      forgejo-cli
      gnupg
      lolcat
      tlrc
      tree
      unzip
      wget
    ]
    # macOS ships pbcopy/pbpaste; shim them onto wl-clipboard on Linux so the
    # same command works everywhere (Neovim, scripts, etc).
    ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
      wl-clipboard
      (writeShellScriptBin "pbcopy" ''exec ${wl-clipboard}/bin/wl-copy "$@"'')
      (writeShellScriptBin "pbpaste" ''exec ${wl-clipboard}/bin/wl-paste "$@"'')
    ];

  services.gpg-agent = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
    enable = true;
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;
  };
}
