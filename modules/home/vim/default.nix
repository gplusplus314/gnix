{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  vim = pkgs.writeShellScriptBin "vim" ''
    exec ${config.programs.neovim.finalPackage}/bin/nvim -u "$HOME/.config/vim/vimrc" "$@"
  '';
in
{
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;
    configFiles = ./nvim;

    extras = {
      ai.copilot.enable = true;
      dap.core.enable = true;
      editor."neo-tree".enable = true;
      formatting.prettier.enable = true;
      lang.go.enable = true;
      lang.nix.enable = true;
      lang.java.enable = true;
      lang.python.enable = true;
      lang.rust.enable = true;
      lang.toml.enable = true;
      lang.typescript.enable = true;
      test.core.enable = true;
    };

    extraPackages = with pkgs; [
      ripgrep
      fd
      lazygit
      nodejs
      statix
      nixfmt
      nixd
    ];
  };

  home.packages = [ vim ];

  xdg.configFile = {
    "vim/vimrc".source = ./vimrc;
    "nvim/stylua.toml".source = ./nvim/stylua.toml;
    "nvim/.neoconf.json".source = ./nvim/.neoconf.json;
    "nvim/.editorconfig".source = ./nvim/.editorconfig;
  };

  home.activation.vimStateDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/state/vim"/{backups,swap,undo}
  '';

  home.sessionVariables.EDITOR = "vim";
}
