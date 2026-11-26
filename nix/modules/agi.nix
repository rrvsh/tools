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
  files = {
    "agi/start".source = root + "/agents/agi/start";
    "agi/turn.ts".source = root + "/agents/agi/turn.ts";
    "agi/self.ts".source = root + "/agents/agi/self.ts";
    "agi/models.json".text = json;
    "agi/settings.json".text = settings;
    "agi/init/SYSTEM.md".source = root + "/agents/agi/init/SYSTEM.md";
    "agi/init/AGENTS.md".source = root + "/agents/agi/init/AGENTS.md";
    "agi/init/seed.md".source = root + "/agents/agi/init/seed.md";
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

      sops.secrets."pi/venice-api-key" = {
        owner = lib.mkForce "root";
        mode = lib.mkForce "0444";
      };

      environment.etc = files // {
        "agi/start" = files."agi/start" // {
          mode = "0755";
        };
      };

      systemd.tmpfiles.rules = [
        "d /home/memory/agi 0700 memory users -"
        "d /var/lib/agi 0700 memory users -"
        "d /var/lib/agi/sessions 0700 memory users -"
        "C /var/lib/agi/models.json 0600 memory users - /etc/agi/models.json"
        "C /var/lib/agi/settings.json 0600 memory users - /etc/agi/settings.json"
      ];

      systemd.services.agi = {
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
          # models.json and settings.json must be real files: a store symlink can not
          # be rewritten and bin/provider swaps models.json. tmpfiles C skips an existing
          # symlink, so a fresh body comes up unswappable. Repair on start.
          ExecStartPre =
            "+"
            + pkgs.writeShellScript "agi-state-repair" ''
              for f in models.json settings.json; do
                [ -L "/var/lib/agi/$f" ] || continue
                cp "/etc/agi/$f" "/var/lib/agi/$f.new"
                mv -f "/var/lib/agi/$f.new" "/var/lib/agi/$f"
                chown memory:users "/var/lib/agi/$f"
                chmod 600 "/var/lib/agi/$f"
              done
              # The upkeep timers are the agent's own business (bin/timers stages them in
              # /run), so a reboot wiping /run must not lose them: restage here.
              for u in agi-alert.service agi-doctor.service agi-doctor.timer agi-snap.service agi-snap.timer agi-restore.service agi-restore.timer; do
                [ -f "/home/memory/agi/systemd/$u" ] && install -m 644 "/home/memory/agi/systemd/$u" "/run/systemd/system/$u"
              done
              systemctl daemon-reload || true
              systemctl --no-block start agi-doctor.timer agi-snap.timer agi-restore.timer || true
            '';
          ExecStart = "/etc/agi/start";
          Restart = "always";
          RestartSec = 5;
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

      security.sudo.extraConfig = "memory ALL=(ALL) NOPASSWD: ALL";

      sops.secrets."pi/venice-api-key" = {
        owner = lib.mkForce "root";
        group = lib.mkForce "staff";
        mode = lib.mkForce "0440";
      };

      environment.etc = files;

      system.activationScripts.postActivation.text = lib.mkAfter ''
        mkdir -p /var/lib/agi/sessions /Users/memory/agi
        chown -R memory:staff /var/lib/agi /Users/memory/agi || true
        chmod 700 /var/lib/agi /var/lib/agi/sessions
        for f in models.json settings.json; do
          if [ ! -f "/var/lib/agi/$f" ] || [ -L "/var/lib/agi/$f" ]; then
            install -o memory -g staff -m 600 "/etc/agi/$f" "/var/lib/agi/$f.new"
            mv -f "/var/lib/agi/$f.new" "/var/lib/agi/$f"
          fi
        done
        touch /var/log/agi.log && chown memory:staff /var/log/agi.log
      '';

      launchd.daemons.agi = {
        serviceConfig = {
          Label = "sh.rrv.agi";
          ProgramArguments = [
            "${pkgs.bash}/bin/bash"
            "/etc/agi/start"
          ];
          EnvironmentVariables = {
            AGI_ROOT = "/Users/memory/agi";
            AGI_INIT = "/etc/agi/init";
            PI_CODING_AGENT_DIR = "/var/lib/agi";
            AGI_MODEL = model;
            AGI_DEBUG = "1";
            HOME = "/Users/memory";
          };
          UserName = "memory";
          GroupName = "staff";
          WorkingDirectory = "/Users/memory/agi";
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          ThrottleInterval = 10;
          ExitTimeOut = 90;
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
    };
}
