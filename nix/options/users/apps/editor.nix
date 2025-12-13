{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  inherit (builtins) mapAttrs;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
in
{
  config.flake = {
    users.userOptions.apps.editor = mkOption {
      type = enum [
        "neovim"
      ];
    };
    modules.homeManager = mapAttrs (
      username: userConfig:
      (
        { pkgs, ... }:
        {
          imports = [ inputs.nvf.homeManagerModules.default ];
          config = mkMerge [
            (mkIf (userConfig.apps.editor == "neovim") {
              programs.neovim = {
                enable = true;
                package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
                defaultEditor = true;
                viAlias = true;
                vimAlias = true;
                extraLuaConfig = "require(\"${username}\")";
              };
              xdg.configFile."nvim/lua".source = root + src/lua;
            })
          ];
        }
      )
    ) cfg.users.users;
  };
}
