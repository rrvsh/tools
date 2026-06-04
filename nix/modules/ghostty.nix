{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.ghostty = {
      home-manager.sharedModules = [ cfg.modules.homeManager.ghostty ];
    };
    nixos.ghostty = {
      home-manager.sharedModules = [ cfg.modules.homeManager.ghostty ];
    };
    homeManager.ghostty =
      { pkgs, ... }:
      {
        programs.ghostty = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
        };
      };
  };
}
