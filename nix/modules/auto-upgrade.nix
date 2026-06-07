let
  flakeRef = "github:rrvsh/tools/prime";
  serviceName = "nh-flake-upgrade";
in
{
  config.flake.modules = {
    darwin.auto-upgrade =
      { config, pkgs, ... }:
      {
        launchd.daemons.${serviceName} = {
          script = ''
            exec ${pkgs.nh}/bin/nh darwin switch ${flakeRef} \
              --hostname ${config.networking.hostName} \
              --refresh \
              --bypass-root-check
          '';
          serviceConfig = {
            RunAtLoad = true;
            StartInterval = 86400;
            StandardOutPath = "/var/log/${serviceName}.log";
            StandardErrorPath = "/var/log/${serviceName}.err.log";
          };
        };
      };
    nixos.auto-upgrade =
      { config, pkgs, ... }:
      {
        systemd = {
          services.${serviceName} = {
            description = "Upgrade system from flake with nh";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            path = [ pkgs.nh ];
            script = ''
              exec nh os switch ${flakeRef} \
                --hostname ${config.networking.hostName} \
                --refresh
            '';
            serviceConfig.Type = "oneshot";
          };
          timers.${serviceName} = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "15min";
              OnUnitActiveSec = "24h";
              RandomizedDelaySec = "1h";
              Persistent = true;
            };
          };
        };
      };
  };
}
