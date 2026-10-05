{ config, lib, ... }:
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
    darwin.agent-browser-shared = lib.recursiveUpdate osModule {
      homebrew.casks = [ "google-chrome" ];
    };
    nixos.agent-browser-shared = osModule;
    homeManager.agent-browser-shared =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.services.agent-browser-shared;
        isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
        profileRoot = lib.removeSuffix "/" cfg.profileRoot;
        normalBrowserRoot =
          if isDarwin then
            "${config.home.homeDirectory}/Library/Application Support/Google/Chrome"
          else
            "${config.home.homeDirectory}/.config/chromium";
        stateDirectory = "${config.xdg.stateHome}/agent-browser-shared";
        browserArguments = [
          "--headless=new"
          "--user-data-dir=${profileRoot}"
          "--profile-directory=Default"
          "--remote-debugging-address=127.0.0.1"
          "--remote-debugging-port=${toString cfg.port}"
          "--no-first-run"
          "--no-default-browser-check"
          "about:blank"
        ];
      in
      {
        options.services.agent-browser-shared = {
          enable = lib.mkEnableOption "a persistent Chrome process shared by pinned agent-browser CDP sessions";
          chromeExecutable = lib.mkOption {
            type = lib.types.str;
            default =
              if isDarwin then
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
              else
                lib.getExe pkgs.chromium;
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

        config = lib.mkIf cfg.enable (
          lib.mkMerge [
            {
              assertions = [
                {
                  assertion =
                    profileRoot != normalBrowserRoot && !(lib.hasPrefix "${normalBrowserRoot}/" profileRoot);
                  message = "services.agent-browser-shared.profileRoot must not use a path inside the normal browser user-data directory.";
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

              programs.pi-coding-agent.context = lib.mkAfter ''

                ### Shared authenticated browser

                - Normal `agent_browser` calls attach to the persistent shared browser on loopback port ${toString cfg.port}.
                - Each Pi session has a separate pinned tab. Do not run concurrent commands against the same pinned browser session.
                - Do not adopt an unfamiliar tab or target ID. If the pinned tab is gone, create a new tab instead.
                - Shared-browser tabs have separate navigation but share cookies, storage, service workers, and login state.
                - Never run global `cookies clear`, clear all browsing data, or delete the shared browser profile. These actions sign every shared workflow out of every site.
                - Do not log out, switch accounts, clear origin storage, or make other profile-wide authentication changes without explicit approval.
                - The CDP endpoint grants full browser control. Never expose or forward port ${toString cfg.port} beyond loopback.
              '';
            }
            (lib.mkIf isDarwin {
              launchd.agents.agent-browser-shared = {
                enable = true;
                config = {
                  ProgramArguments = [ cfg.chromeExecutable ] ++ browserArguments;
                  RunAtLoad = true;
                  KeepAlive = false;
                  ProcessType = "Background";
                  StandardOutPath = "${stateDirectory}/chrome.log";
                  StandardErrorPath = "${stateDirectory}/chrome.error.log";
                };
              };
            })
            (lib.mkIf (!isDarwin) {
              systemd.user.services.agent-browser-shared = {
                Unit.Description = "Persistent Chrome for pinned agent-browser CDP sessions";
                Service = {
                  ExecStart = lib.escapeShellArgs ([ cfg.chromeExecutable ] ++ browserArguments);
                  Restart = "on-failure";
                };
                Install.WantedBy = [ "default.target" ];
              };
            })
          ]
        );
      };
  };
}
