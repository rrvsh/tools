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
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
in
{
  config.flake = {
    users.userOptions.apps.editor = mkOption { type = enum [ "nvf" ]; };
    modules.homeManager = mapAttrs (
      username: userConfig:
      (
        { pkgs, ... }:
        {

          imports = [ inputs.nvf.homeManagerModules.default ];
          config = mkIf (userConfig.apps.editor == "nvf") {
            programs.nvf = {
              enable = true;
              defaultEditor = true;
              settings.vim = {
                additionalRuntimePaths = [ src ];
                luaConfigRC.rafiq = "require(\"${username}\")";
                extraPackages = with pkgs; [ ripgrep ];
                utility.snacks-nvim.enable = true;
              };
            };
          };
        }
      )
    ) cfg.users.users;
  };
}
