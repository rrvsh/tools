{ config, inputs, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
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
            path = [ pkgs.systemd ];
            script = ''
              trap 'systemctl start hermes-agent.service' EXIT
              systemctl stop hermes-agent.service
              ${
                cfg.packages.${pkgs.stdenv.hostPlatform.system}.hermes-workspace-cleanup
              }/bin/hermes-workspace-cleanup \
                /var/lib/hermes/workspace \
                /run/hermes-agent-daily-maintenance
              systemctl start hermes-agent.service
              trap - EXIT
            '';
            serviceConfig = hardening // {
              CapabilityBoundingSet = [
                "CAP_DAC_OVERRIDE"
                "CAP_FOWNER"
              ];
              ExecStopPost = "${pkgs.systemd}/bin/systemctl start hermes-agent.service";
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ "/var/lib/hermes/workspace" ];
              RestrictAddressFamilies = [ "AF_UNIX" ];
              RuntimeDirectory = "hermes-agent-daily-maintenance";
              RuntimeDirectoryMode = "0700";
              Type = "oneshot";
              UMask = "0077";
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
