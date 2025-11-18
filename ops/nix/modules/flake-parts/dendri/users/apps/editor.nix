{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg.paths) src;
  inherit (builtins) mapAttrs;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
in
{
  config.flake = {
    users.userOptions.apps.editor = mkOption {
      type = enum [
        "nvf"
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
            (mkIf (userConfig.apps.editor == "nvf") {
              programs.nvf = {
                enable = true;
                defaultEditor = true;
                settings.vim = {
                  additionalRuntimePaths = [ src ];
                  luaConfigRC.${username} = "require(\"${username}\")";
                };
              };
            })
            (mkIf (userConfig.apps.editor == "neovim") {
              programs.neovim = {
                enable = true;
                package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
                defaultEditor = true;
                viAlias = true;
                vimAlias = true;
                extraLuaConfig = "require(\"${username}\")";
              };
              xdg.configFile."nvim/lua".source = src + /lua;
            })
          ];
        }
      )
    ) cfg.users.users;
  };
}
