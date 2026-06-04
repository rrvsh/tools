{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.hosts.darwin.alpha = {
    hostPlatform = "aarch64-darwin";
    profiles = [
      "graphical"
      "development"
    ];
    modules = [
      cfg.modules.darwin.rafiq
      cfg.modules.darwin.rosetta-builder
      { system.primaryUser = "rafiq"; }
    ];
  };
}
