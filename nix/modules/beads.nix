{ config, inputs, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.beads.home-manager.sharedModules = [ cfg.modules.homeManager.beads ];
    nixos.beads.home-manager.sharedModules = [ cfg.modules.homeManager.beads ];
    homeManager.beads =
      { hostName, pkgs, ... }:
      {
        home = {
          packages = [ inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default ];
          sessionVariables = {
            BD_DISABLE_EVENT_FLUSH = "1";
            BD_DISABLE_METRICS = "1";
            BEADS_ACTOR = hostName;
          };
        };
        systemd.user.sessionVariables = {
          BD_DISABLE_EVENT_FLUSH = "1";
          BD_DISABLE_METRICS = "1";
          BEADS_ACTOR = hostName;
        };
      };
  };
}
