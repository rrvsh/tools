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
            fidget-nvim
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
          ];
        };
      };
  };
}
