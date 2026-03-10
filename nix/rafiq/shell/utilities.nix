{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.homeManager.rafiq = {
    imports = with cfg.modules.homeManager; [
      fish
      git
    ];
  };
}
