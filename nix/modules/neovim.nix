{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.neovim ];
  };
in
{
  config.flake.modules = {
    darwin.neovim = osModule;
    nixos.neovim = osModule;
    homeManager.neovim =
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
  };
}
