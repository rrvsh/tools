_:
let
  flakeRef = "github:rrvsh/tools/prime";
  serviceName = "nh-flake-upgrade";
in
{
  config.flake.modules = {
    darwin.auto-upgrade =
      { config, pkgs, ... }:
      {
        environment = {
          systemPackages = [ pkgs.nh ];
          variables.NH_FLAKE = flakeRef;
        };
        launchd.daemons.${serviceName} = {
          script = ''
            exec ${pkgs.nh}/bin/nh darwin switch ${flakeRef} \
              --hostname ${config.networking.hostName} \
              --refresh \
              --no-nom \
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
        programs.nh = {
          enable = true;
          flake = flakeRef;
        };
        systemd = {
          services.${serviceName} = {
            description = "Upgrade system from flake with nh";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            path = [
              config.nix.package
              config.programs.ssh.package
              pkgs.gitMinimal
              pkgs.nh
            ];
            script = ''
              exec nh os switch ${flakeRef} \
                --hostname ${config.networking.hostName} \
                --refresh \
                --no-nom
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
