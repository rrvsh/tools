{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.flake;
  root = cfg.paths.root;
  model = "deepseek-v4-1-flash-1017-uncensored";
  json = builtins.toJSON {
    providers.venice = {
      baseUrl = "https://api.venice.ai/api/v1";
      api = "openai-completions";
      apiKey = "!cat /run/secrets/pi/venice-api-key";
      models = [
        { id = model; }
        { id = "deepseek-v4-pro-0813"; }
        { id = "qwen3-coder-480b-a35b-instruct-turbo"; }
        { id = "openai-gpt-53-codex"; }
      ];
    };
  };
  settings = builtins.toJSON {
    codemode = {
      mode = "only";
    };
  };
in
{
  options.flake.agi = {
    enable = lib.mkEnableOption "AGI agent";
    model = lib.mkOption {
      type = lib.types.str;
      default = model;
    };
  };

  config.flake.modules.nixos.agi =
    {
      pkgs,
      primaryUser,
      ...
    }:
    {
      # A user per machine, so the agent inhabits the host rather than a shell.
      users.users.memory = {
        isNormalUser = true;
        home = "/home/memory";
        shell = pkgs.bash;
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "render"
          "audio"
        ];
        openssh.authorizedKeys.keys = primaryUser.sshAuthorizedKeys;
      };

      # Full root, no password: the whole point of the agent.
      security.sudo.wheelNeedsPassword = false;
      security.sudo.extraRules = [
        {
          users = [ "memory" ];
          commands = [
            {
              command = "ALL";
              options = [
                "NOPASSWD"
                "SETENV"
              ];
            }
          ];
        }
      ];

      # Widen the key the pi-agent module already declares rather than copying it.
      sops.secrets."pi/venice-api-key" = {
        owner = lib.mkForce "root";
        mode = lib.mkForce "0444";
      };

      environment.etc = {
        "agi/start" = {
          source = root + "/agents/agi/start";
          mode = "0755";
        };
        "agi/turn.ts".source = root + "/agents/agi/turn.ts";
        "agi/self.ts".source = root + "/agents/agi/self.ts";
        "agi/models.json".text = json;
        "agi/settings.json".text = settings;
        "agi/init/SYSTEM.md".source = root + "/agents/agi/init/SYSTEM.md";
        "agi/init/AGENTS.md".source = root + "/agents/agi/init/AGENTS.md";
        "agi/init/seed.md".source = root + "/agents/agi/init/seed.md";
      };

      systemd = {
        tmpfiles.rules = [
          "d /var/backups/agi 0700 memory users -"
          "d /home/memory/agi 0700 memory users -"
          "d /var/lib/agi 0700 memory users -"
          "d /var/lib/agi/sessions 0700 memory users -"
          "C /var/lib/agi/models.json 0600 memory users - /etc/agi/models.json"
          "C /var/lib/agi/settings.json 0600 memory users - /etc/agi/settings.json"
        ];

        services = {
          agi = {
            description = "AGI agent";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [
              "network-online.target"
              "sops-install-secrets.service"
            ];
            path = [
              inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent
              pkgs.nodejs
              pkgs.git
              pkgs.curl
              pkgs.procps
              pkgs.hostname
              pkgs.bash
              pkgs.coreutils
              pkgs.systemd
            ];
            environment = {
              HOME = "/home/memory";
              PI_CODING_AGENT_DIR = "/var/lib/agi";
              PI_SKIP_VERSION_CHECK = "1";
              PI_TELEMETRY = "0";
              AGI_MODEL = model;
            };
            unitConfig.StartLimitIntervalSec = 0;
            serviceConfig = {
              Type = "notify";
              NotifyAccess = "all";
              WatchdogSec = 180;
              User = "memory";
              Group = "users";
              WorkingDirectory = "/home/memory/agi";
              ExecStart = "/etc/agi/start";
              Restart = "always";
              RestartSec = 5;
              # Exponential backoff so a broken seed does not hot-loop.
              RestartSteps = 6;
              RestartMaxDelaySec = 300;
              KillMode = "mixed";
              TimeoutStopSec = 90;
              OOMPolicy = "continue";
              OOMScoreAdjust = -900;
              RuntimeDirectory = "agi";
              RuntimeDirectoryMode = "0700";
              UMask = "0077";
              LimitNOFILE = 65536;
              Nice = -5;
              IOWeight = 200;
              SyslogIdentifier = "agi";
            };
          };

          # Wick's own upkeep. Units staged from the repo land in /run only, so the
          # durable copy is declared here: snapshot nightly, doctor hourly, alert on failure.
          agi-snap = {
            description = "AGI snapshot to /var/backups/agi and mercury";
            onFailure = [ "agi-alert.service" ];
            serviceConfig = {
              Type = "oneshot";
              User = "memory";
              Group = "users";
              WorkingDirectory = "/home/memory/agi";
              ExecStart = "/home/memory/agi/bin/snap --remote";
            };
          };

          agi-doctor = {
            description = "AGI health gate";
            onFailure = [ "agi-alert.service" ];
            serviceConfig = {
              Type = "oneshot";
              User = "memory";
              Group = "users";
              WorkingDirectory = "/home/memory/agi";
              ExecStart = "/home/memory/agi/bin/doctor";
            };
          };

          agi-restore = {
            description = "AGI restore drill";
            onFailure = [ "agi-alert.service" ];
            serviceConfig = {
              Type = "oneshot";
              User = "memory";
              Group = "users";
              WorkingDirectory = "/home/memory/agi";
              ExecStart = "/home/memory/agi/bin/restore-drill";
            };
          };

          agi-alert = {
            description = "AGI failure alert to Rafiq";
            serviceConfig = {
              Type = "oneshot";
              User = "memory";
              Group = "users";
              WorkingDirectory = "/home/memory/agi";
              ExecStart = "/home/memory/agi/bin/alert systemd";
            };
          };
        };

        timers = {
          agi-snap = {
            description = "Daily AGI snapshot";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 03:00:00 UTC";
              AccuracySec = "5m";
              Persistent = true;
            };
          };

          agi-doctor = {
            description = "Hourly AGI doctor";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "hourly";
              AccuracySec = "1m";
              Persistent = true;
              OnBootSec = "3min";
            };
          };

          agi-restore = {
            description = "Monthly AGI restore drill";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "monthly";
              AccuracySec = "5m";
              Persistent = true;
            };
          };
        };
      };
    };

  config.flake.modules.darwin.agi =
    {
      pkgs,
      primaryUser,
      ...
    }:
    {
      users.users.memory = {
        isHidden = true;
        uid = 512;
        home = "/Users/memory";
        shell = "/bin/bash";
        openssh.authorizedKeys.keys = primaryUser.sshAuthorizedKeys;
      };
      users.knownUsers = [ "memory" ];

      # memory is in staff, so widen the shared key instead of copying it.
      sops.secrets."pi/venice-api-key" = {
        owner = lib.mkForce "root";
        group = lib.mkForce "staff";
        mode = lib.mkForce "0440";
      };

      security.sudo.extraConfig = "memory ALL=(ALL) NOPASSWD: ALL";

      environment.etc = {
        "agi/start".source = root + "/agents/agi/start";
        "agi/turn.ts".source = root + "/agents/agi/turn.ts";
        "agi/self.ts".source = root + "/agents/agi/self.ts";
        "agi/models.json".text = json;
        "agi/settings.json".text = settings;
        "agi/init/SYSTEM.md".source = root + "/agents/agi/init/SYSTEM.md";
        "agi/init/AGENTS.md".source = root + "/agents/agi/init/AGENTS.md";
        "agi/init/seed.md".source = root + "/agents/agi/init/seed.md";
      };

      # No tmpfiles on Darwin: create state once, at activation.
      system.activationScripts.postActivation.text = lib.mkAfter ''
        mkdir -p /var/lib/agi/sessions /var/backups/agi /Users/memory/agi
        chown memory:staff /var/lib/agi /var/backups/agi /Users/memory || true
        chmod 700 /var/lib/agi /var/lib/agi/sessions /var/backups/agi
        touch /var/log/agi.log && chown memory:staff /var/log/agi.log
        for f in models.json settings.json; do
          [ -f "/var/lib/agi/$f" ] || install -o memory -g staff -m 600 "/etc/agi/$f" "/var/lib/agi/$f"
        done
      '';

      launchd.daemons = {
        agi = {
          serviceConfig = {
            Label = "sh.rrv.agi";
            ProgramArguments = [
              "${pkgs.bash}/bin/bash"
              "/etc/agi/start"
            ];
            EnvironmentVariables = {
              AGI_ROOT = "/Users/memory/agi";
            AGI_DEBUG = "1";
              AGI_INIT = "/etc/agi/init";
              PI_CODING_AGENT_DIR = "/var/lib/agi";
              AGI_MODEL = model;
              HOME = "/Users/memory";
            };
            UserName = "memory";
            GroupName = "staff";
            WorkingDirectory = "/Users/memory/agi";
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 10;
            ExitTimeOut = 90;
            # Background throttles timers hard; the turn scheduler is a timer.
            ProcessType = "Interactive";
            StandardOutPath = "/var/log/agi.log";
            StandardErrorPath = "/var/log/agi.log";
          };
          path = [
            pkgs.bash
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.findutils
            pkgs.curl
            pkgs.procps
            pkgs.git
            pkgs.nodejs
            inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent
          ];
        };

        agi-snap = {
          serviceConfig = {
            Label = "sh.rrv.agi.snap";
            ProgramArguments = [
              "/bin/bash"
              "/Users/memory/agi/bin/snap"
              "--remote"
            ];
            UserName = "memory";
            GroupName = "staff";
            WorkingDirectory = "/Users/memory/agi";
            StartCalendarInterval = [
              {
                Hour = 3;
                Minute = 0;
              }
            ];
            StandardOutPath = "/var/log/agi.log";
            StandardErrorPath = "/var/log/agi.log";
          };
          path = [
            pkgs.nodejs
            pkgs.git
          ];
        };

        agi-doctor = {
          serviceConfig = {
            Label = "sh.rrv.agi.doctor";
            ProgramArguments = [
              "/bin/bash"
              "/Users/memory/agi/bin/doctor"
            ];
            UserName = "memory";
            GroupName = "staff";
            WorkingDirectory = "/Users/memory/agi";
            StartCalendarInterval = [
              {
                Minute = 17;
              }
            ];
            StandardOutPath = "/var/log/agi.log";
            StandardErrorPath = "/var/log/agi.log";
          };
          path = [
            pkgs.nodejs
            pkgs.git
          ];
        };
      };
    };
}
