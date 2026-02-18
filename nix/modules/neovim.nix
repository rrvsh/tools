{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.paths) root;
in
{
  config.flake = {
    modules.homeManager.rafiq =
      { pkgs, ... }:
      let
        epub-nvim = pkgs.vimUtils.buildVimPlugin {
          pname = "epub.nvim";
          version = "main";
          src = inputs.epub-nvim;
        };
      in
      {
        xdg.configFile."nvim/lua".source = root + /nvim;
        programs.neovim = {
          enable = true;
          package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          initLua = "require(\"rafiq\")";
          plugins = with pkgs.vimPlugins; [
            inputs.fff-nvim.packages.${pkgs.stdenv.hostPlatform.system}.fff-nvim
            fidget-nvim
            mini-nvim
            nvim-lspconfig
            plenary-nvim
            which-key-nvim
            yazi-nvim
            epub-nvim
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
