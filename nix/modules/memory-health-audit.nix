{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    nixos.memory-health-audit = {
      home-manager.sharedModules = [ cfg.modules.homeManager.memory-health-audit ];
    };
    homeManager.memory-health-audit =
      { config, pkgs, ... }:
      let
        audit = cfg.packages.${pkgs.stdenv.hostPlatform.system}.memory-health-audit;
        reportDirectory = "${config.home.homeDirectory}/Agents/research/memory-audit";
      in
      {
        home = {
          activation.memoryHealthAuditReportDirectory = config.lib.dag.entryAfter [ "writeBoundary" ] ''
            run ${pkgs.coreutils}/bin/install -d -m 0700 ${reportDirectory}
          '';
          packages = [ audit ];
        };
        systemd.user = {
          services.memory-health-audit = {
            Unit = {
              Description = "Audit the shared agent memory tree without editing it";
              After = [ "syncthing.service" ];
              ConditionPathIsDirectory = "%h/Agents/memory";
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${audit}/bin/memory-health-audit --offline";
              WorkingDirectory = "%h";
              UMask = "0077";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = "read-only";
              ProtectSystem = "strict";
              ReadWritePaths = [ reportDirectory ];
              RestrictAddressFamilies = [ "AF_UNIX" ];
            };
          };
          timers.memory-health-audit = {
            Unit.Description = "Run the shared memory health audit weekly";
            Timer = {
              OnCalendar = "Sun *-*-* 04:00:00";
              RandomizedDelaySec = "2h";
              AccuracySec = "15m";
              Persistent = false;
              Unit = "memory-health-audit.service";
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };
      };
  };
}
