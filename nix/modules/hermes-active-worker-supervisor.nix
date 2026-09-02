_: {
  config.flake.modules.nixos.hermes-active-worker-supervisor =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.hermes-agent;
      hermesHome = "${cfg.stateDir}/.hermes";
      jobName = "active-worker-heartbeat";
      deliveryTarget = "telegram:384288005";
      prompt = pkgs.writeText "hermes-active-worker-supervisor-prompt" (
        builtins.replaceStrings [ "@HERMES_HOME@" ] [ hermesHome ] (
          builtins.readFile ./hermes-active-worker-supervisor/prompt.txt
        )
      );
      workerRegistry = pkgs.writeShellApplication {
        name = "hermes-worker";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          export HERMES_HOME=${lib.escapeShellArg hermesHome}
          export HERMES_ACTIVE_WORKER_DIR=${lib.escapeShellArg "${hermesHome}/active-workers"}
          exec python3 ${./hermes-active-worker-supervisor/worker_registry.py} "$@"
        '';
      };
      reconcile = pkgs.writeShellApplication {
        name = "reconcile-hermes-active-worker-supervisor";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.jq
        ];
        text = ''
          exec ${pkgs.bash}/bin/bash ${./hermes-active-worker-supervisor/reconcile.sh}
        '';
      };
    in
    {
      assertions = [
        {
          assertion = cfg.enable;
          message = "hermes-active-worker-supervisor requires services.hermes-agent.enable.";
        }
        {
          assertion = !cfg.container.enable;
          message = "hermes-active-worker-supervisor requires native Hermes Agent mode.";
        }
      ];

      services.hermes-agent = {
        extraPackages = [ pkgs.gh ];
        hermesHomeFiles."scripts/active-worker-supervisor.py" =
          ./hermes-active-worker-supervisor/supervisor.py;
      };

      environment.systemPackages = [ workerRegistry ];

      systemd.services.hermes-agent = {
        requires = [ "hermes-active-worker-supervisor.service" ];
        after = [ "hermes-active-worker-supervisor.service" ];
      };

      systemd.services.hermes-active-worker-supervisor = {
        description = "Reconcile the Hermes active-worker supervisor cron job";
        wantedBy = [ "multi-user.target" ];
        before = [ "hermes-agent.service" ];
        after = [ "local-fs.target" ];
        environment = {
          HERMES_BIN = "${cfg.package}/bin/hermes";
          HERMES_HOME = hermesHome;
          HERMES_JOB_DELIVERY = deliveryTarget;
          HERMES_JOB_NAME = jobName;
          HERMES_JOB_PROMPT = prompt;
          HOME = config.users.users.${cfg.user}.home;
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = cfg.group;
          UMask = "0007";
          ExecStart = lib.getExe reconcile;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = "read-only";
          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.stateDir ];
        };
      };
    };
}
