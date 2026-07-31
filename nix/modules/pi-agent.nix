{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.pi-agent ];
  };
in
{
  config.flake.modules = {
    darwin.pi-agent = osModule;
    nixos.pi-agent = osModule;
    homeManager.pi-agent =
      { pkgs, config, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        agentBrowser = inputs.agent-browser.packages.${system}.agent-browser;
        slopchop = inputs.pi-slopchop.packages.${system}.pi-slopchop;
        sessionDrain = inputs.pi-session-drain.packages.${system}.pi-session-drain;
        piPackage = inputs.pi.packages.${system}.pi-coding-agent;
        sessionDrainRun = pkgs.writeShellApplication {
          name = "pi-session-drain-run";
          runtimeInputs = [ piPackage ];
          text = ''
            export PI_OFFLINE=1
            export PI_SKIP_VERSION_CHECK=1
            export PI_SESSION_DRAIN_MAX_SESSIONS=''${PI_SESSION_DRAIN_MAX_SESSIONS:-1}
            export PI_SESSION_DRAIN_MAX_CHUNKS_PER_SESSION=''${PI_SESSION_DRAIN_MAX_CHUNKS_PER_SESSION:-80}
            export PI_SESSION_DRAIN_CHUNK_CONCURRENCY=''${PI_SESSION_DRAIN_CHUNK_CONCURRENCY:-4}
            export PI_SESSION_DRAIN_TIMEOUT_MS=''${PI_SESSION_DRAIN_TIMEOUT_MS:-7200000}

            exec pi --no-session -p '/session-drain:run'
          '';
        };
        # NixOS cannot run agent-browser's downloaded generic Chrome, so point the
        # extension at Nix-provided Chromium for fresh browser launches by default.
        agentBrowserConfig = {
          version = 1;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          browser.executablePath = "${pkgs.chromium}/bin/chromium";
        };
        homeDirectory = config.home.homeDirectory;
        inherit (cfg.paths) root;
      in
      {
        home = {
          packages = [
            agentBrowser
            sessionDrainRun
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ];
          file = {
            ".pi/config/pi-agent-browser-native/config.json".text = builtins.toJSON agentBrowserConfig;
            # Note: this does not show up in the loaded context files, but it is appended to the system prompt.
            ".pi/agent/APPEND_SYSTEM.md".source =
              config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/Agents/MEMORY.md";
          };
        };
        systemd.user.services.pi-session-drain = {
          Unit.Description = "Drain Pi sessions into agent memory";
          Service = {
            Type = "oneshot";
            WorkingDirectory = homeDirectory;
            ExecStart = "${sessionDrainRun}/bin/pi-session-drain-run";
            TimeoutStartSec = "2h 15m";
          };
        };
        systemd.user.timers.pi-session-drain = {
          Unit.Description = "Run Pi session drain daily";
          Timer = {
            OnCalendar = "daily";
            OnBootSec = "30m";
            RandomizedDelaySec = "2h";
            AccuracySec = "15m";
            Persistent = false;
            Unit = "pi-session-drain.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
        programs.pi-coding-agent = {
          enable = true;
          package = inputs.pi.packages.${system}.pi-coding-agent;
          extraPackages = [
            pkgs.nodejs_22
            agentBrowser
          ];
          settings = {
            lastChangelogVersion = lib.getVersion config.programs.pi-coding-agent.package;
            extensions = [
              (root + "/pi/extensions/hostname-context.ts")
              (root + "/pi/extensions/system-prompt-viewer.ts")
            ];
            packages = [
              # Keep this pinned with the agent-browser flake input: pi-agent-browser-native
              # tracks specific agent-browser CLI versions in its command surface and result parsing.
              "npm:pi-agent-browser-native@0.2.64"
              "npm:pi-mcp-adapter"
              "npm:pi-subagents"
              "npm:pi-web-access"
              "npm:pi-context-breadcrumbs"
              "npm:context-mode"
              slopchop.passthru.packagePath
              sessionDrain.passthru.packagePath
            ];
          };
        };
      };
  };
}
