{ config, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [
      cfg.modules.homeManager.agent-browser-shared
      { services.agent-browser-shared.enable = true; }
    ];
  };
in
{
  config.flake.modules = {
    darwin.agent-browser-shared = osModule;
    homeManager.agent-browser-shared =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.services.agent-browser-shared;
        profileRoot = lib.removeSuffix "/" cfg.profileRoot;
        normalChromeRoot = "${config.home.homeDirectory}/Library/Application Support/Google/Chrome";
        stateDirectory = "${config.xdg.stateHome}/agent-browser-shared";
      in
      {
        options.services.agent-browser-shared = {
          enable = lib.mkEnableOption "a persistent Chrome process shared by pinned agent-browser CDP sessions";
          chromeExecutable = lib.mkOption {
            type = lib.types.str;
            default = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
            description = "Chrome executable used by the shared browser service.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 9222;
            description = "Loopback Chrome DevTools Protocol port.";
          };
          profileRoot = lib.mkOption {
            type = lib.types.str;
            default = "${config.home.homeDirectory}/.agent-browser/profiles/shared";
            description = "Dedicated Chrome user-data root. This must not be the normal Chrome user-data directory.";
          };
        };

        config = lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = pkgs.stdenv.hostPlatform.isDarwin;
              message = "services.agent-browser-shared is currently supported only on Darwin.";
            }
            {
              assertion = profileRoot != normalChromeRoot && !(lib.hasPrefix "${normalChromeRoot}/" profileRoot);
              message = "services.agent-browser-shared.profileRoot must not use a path inside the normal Chrome user-data directory.";
            }
          ];

          home = {
            activation.agentBrowserSharedDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg profileRoot} ${lib.escapeShellArg stateDirectory}
            '';
            sessionVariables = {
              AGENT_BROWSER_PROFILE = lib.mkForce null;
              AGENT_BROWSER_CDP = toString cfg.port;
              AGENT_BROWSER_PIN_TAB = "1";
            };
          };

          launchd.agents.agent-browser-shared = {
            enable = true;
            config = {
              ProgramArguments = [
                cfg.chromeExecutable
                "--headless=new"
                "--user-data-dir=${profileRoot}"
                "--profile-directory=Default"
                "--remote-debugging-address=127.0.0.1"
                "--remote-debugging-port=${toString cfg.port}"
                "--no-first-run"
                "--no-default-browser-check"
                "about:blank"
              ];
              RunAtLoad = true;
              KeepAlive = false;
              ProcessType = "Background";
              StandardOutPath = "${stateDirectory}/chrome.log";
              StandardErrorPath = "${stateDirectory}/chrome.error.log";
            };
          };

          programs.pi-coding-agent.context = lib.mkAfter ''

            ### Shared authenticated browser

            - Normal `agent_browser` calls attach to the persistent shared browser on loopback port ${toString cfg.port}.
            - Each Pi session has a separate pinned tab. Do not run concurrent commands against the same pinned browser session.
            - Do not adopt an unfamiliar tab or target ID. If the pinned tab is gone, create a new tab instead.
            - Shared-browser tabs have separate navigation but share cookies, storage, service workers, and login state.
            - Do not log out, clear cookies, switch accounts, or perform other profile-wide authentication changes without explicit approval.
            - The CDP endpoint grants full browser control. Never expose or forward port ${toString cfg.port} beyond loopback.
          '';
        };
      };
  };
}
