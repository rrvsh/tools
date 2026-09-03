{ config, inputs, ... }:
let
  inherit (config.flake.paths) root;
in
{
  config.flake.modules.nixos.hermes-agent =
    {
      config,
      hostName,
      lib,
      pkgs,
      ...
    }:
    let
      cheapModel = {
        model = "deepseek/deepseek-v4-flash-0731";
        provider = "openrouter";
      };
      delegationModel = {
        model = "gpt-5.6-luna";
        provider = "openai-codex";
      };
      beadsPackage = inputs.beads.packages.${pkgs.stdenv.hostPlatform.system}.default;
      hardening = {
        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryMax = "3G";
        PrivateDevices = true;
        ProtectControlGroups = true;
        ProtectHome = false;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        TasksMax = 512;
      };
    in
    {
      imports = [ inputs.hermes-agent.nixosModules.default ];
      services.hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal;
        extraDependencyGroups = [ "messaging" ];
        backend.mode = "none";
        user = "rafiq";
        group = "users";
        createUser = false;
        environmentFiles = [ config.sops.secrets."hermes/env".path ];
        extraPackages = [
          beadsPackage
          pkgs.curl
          pkgs.jq
          pkgs.openssh
          pkgs.ripgrep
        ];
        settings = {
          model = {
            default = "gpt-5.6-sol";
            provider = "openai-codex";
          };
          fallback_providers = [ cheapModel ];
          auxiliary =
            lib.genAttrs [
              "approval"
              "compression"
              "curator"
              "goal_judge"
              "kanban_decomposer"
              "mcp"
              "memory_query_rewrite"
              "moa_aggregator"
              "moa_reference"
              "monitor"
              "profile_describer"
              "skills_hub"
              "title_generation"
              "triage_specifier"
              "tts_audio_tags"
              "web_extract"
            ] (_: cheapModel)
            // {
              background_review = cheapModel // {
                enabled = true;
              };
              vision = {
                model = "qwen/qwen3.7-flash";
                provider = "openrouter";
              };
            };
          delegation = delegationModel;
          mcp_servers.linear = {
            url = "https://mcp.linear.app/mcp";
            auth = "oauth";
            sampling.enabled = false;
          };
          memory.write_approval = true;
          skills.write_approval = true;
          cron = {
            inherit (cheapModel) model;
            model_provider = cheapModel.provider;
          };
        };
      };
      sops.secrets."hermes/env" = {
        sopsFile = root + "/sops/hermes.yaml";
        owner = "rafiq";
        group = "users";
        mode = "0400";
      };
      systemd = {
        services = {
          hermes-agent = {
            environment = {
              BD_DISABLE_EVENT_FLUSH = "1";
              BD_DISABLE_METRICS = "1";
              BEADS_ACTOR = hostName;
              HOME = lib.mkForce "/home/rafiq";
            };
            serviceConfig = hardening // {
              ReadWritePaths = lib.mkForce [
                "/var/lib/hermes"
                "/home/rafiq"
              ];
            };
          };
          hermes-agent-daily-maintenance = {
            description = "Clean Hermes build outputs and restart Hermes Agent";
            path = [
              pkgs.coreutils
              pkgs.findutils
              pkgs.jq
              pkgs.systemd
              pkgs.util-linux
            ];
            script = ''
              mount_snapshot=/run/hermes-agent-daily-maintenance
              trap 'systemctl start hermes-agent.service' EXIT
              systemctl stop hermes-agent.service
              findmnt --json --output TARGET >"$mount_snapshot/findmnt.json"
              jq --raw-output0 -e \
                '.filesystems[] | recurse(.children[]?) | .target' \
                "$mount_snapshot/findmnt.json" >"$mount_snapshot/targets"
              [[ -s "$mount_snapshot/targets" ]]
              find /var/lib/hermes/workspace -xdev -type d \
                \( -name target -o -name node_modules -o -name .venv -o -name .cargo-home \) \
                -prune -print0 >"$mount_snapshot/candidates"
              while IFS= read -r -d "" path; do
                has_mount=""
                while IFS= read -r -d "" mount; do
                  if
                    [[ "$mount" == "$path" || "$mount" == "$path/"* ]] \
                      || [[ "$mount" != "/" && "$path" == "$mount/"* ]]
                  then
                    has_mount=1
                    break
                  fi
                done <"$mount_snapshot/targets"
                if [[ -n "$has_mount" ]]; then
                  echo "Skipping build directory with a mount: $path" >&2
                else
                  rm -rf --one-file-system -- "$path"
                fi
              done <"$mount_snapshot/candidates"
              systemctl start hermes-agent.service
              trap - EXIT
            '';
            serviceConfig = {
              NoNewPrivileges = true;
              PrivateDevices = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ "/var/lib/hermes/workspace" ];
              RuntimeDirectory = "hermes-agent-daily-maintenance";
              RuntimeDirectoryMode = "0700";
              Type = "oneshot";
            };
          };
        };
        timers.hermes-agent-daily-maintenance = {
          description = "Run daily Hermes maintenance at 02:00 Asia/Singapore";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 02:00:00 Asia/Singapore";
            Persistent = true;
          };
        };
      };
    };
}
