{ config, primaryUsers, ... }:
let
  cfg = config.flake;
in
{
  config.flake.hosts.darwin.alpha = {
    hostPlatform = "aarch64-darwin";
    primaryUser = primaryUsers.rafiq;
    profiles = [
      "graphical"
      "development"
    ];
    modules = [
      cfg.modules.darwin.user-primary
      cfg.modules.darwin.agent-browser-shared
      cfg.modules.darwin.rosetta-builder
      cfg.modules.darwin.slskd
      cfg.modules.darwin.musicgrabber
    ];
  };
}
