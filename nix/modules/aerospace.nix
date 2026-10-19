{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.aerospace = {
      home-manager.sharedModules = [ cfg.modules.homeManager.aerospace ];
    };
    homeManager.aerospace = {
      programs.aerospace = {
        enable = true;
        launchd.enable = true;
      };
    };
  };
}
