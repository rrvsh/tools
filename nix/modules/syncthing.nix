{ config, ... }:
let
  cfg = config.flake;
  tailscaleAddresses = {
    alpha = "100.103.246.12";
    mercury = "100.127.209.56";
    nemesis = "100.98.114.23";
  };
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.syncthing ];
  };
in
{
  config.flake.modules = {
    darwin.syncthing = osModule;
    nixos.syncthing =
      { primaryUser, ... }:
      {
        imports = [ osModule ];
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22000 ];
        users.users.${primaryUser.name}.linger = true;
      };
    homeManager.syncthing =
      {
        hostName,
        lib,
        ...
      }:
      {
        services.syncthing = {
          enable = true;
          guiAddress = "127.0.0.1:8384";
          overrideDevices = true;
          overrideFolders = true;
          settings.options = {
            autoUpgradeIntervalH = 0;
            globalAnnounceEnabled = false;
            localAnnounceEnabled = false;
            natEnabled = false;
            relaysEnabled = false;
            urAccepted = -1;
            listenAddresses = lib.optional (builtins.hasAttr hostName tailscaleAddresses) "tcp://${tailscaleAddresses.${hostName}}:22000";
          };
        };
      };
  };
}
