{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  config.flake.modules.homeManager.neovim =
    { pkgs, ... }:
    {
      xdg.configFile."nvim/lua".source = root + /nvim;
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        initLua = ''require("rafiq")'';
        plugins = with pkgs.vimPlugins; [
          fff-nvim
          fidget-nvim
          gitsigns-nvim
          mini-nvim
          nvim-lspconfig
          plenary-nvim
          which-key-nvim
          yazi-nvim
        ];
        extraPackages = with pkgs; [
          cargo
          clippy
          lua-language-server
          nil
          pyright
          ruff
          rust-analyzer
          rustc
          rustfmt
          stylua
          unzip
        ];
      };
    };
}
