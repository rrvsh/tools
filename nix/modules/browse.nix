{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.flake;
  extensionId = "mfnicocicmmlkpjnaffgihfjhdgjkdjg";
in
{
  config.flake.modules = {
    darwin.browse = {
      home-manager.sharedModules = [ cfg.modules.homeManager.browse ];
      homebrew.casks = [ "google-chrome" ];
      environment.variables.OPENCODE_BROWSER_MACOS_HANDOFF_APP = "Google Chrome";
    };
    nixos.browse = {
      home-manager.sharedModules = [ cfg.modules.homeManager.browse ];
    };
    homeManager.browse =
      {
        config,
        hostName,
        pkgs,
        ...
      }:
      let
        browse =
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode-browse.overrideAttrs
            (old: {
              patches = (old.patches or [ ]) ++ [
                ../packages/patches/browse-macos-hide-after-handoff.patch
                ../packages/patches/browse-hyprland-handoff.patch
              ];
            });
        remoteBrowseServers = builtins.listToAttrs (
          map (remoteHost: {
            name = "${remoteHost}-browse";
            value = {
              command = lib.getExe pkgs.openssh;
              args = [
                "-T"
                "-o"
                "BatchMode=yes"
                "-o"
                "ConnectTimeout=5"
                "-o"
                "ServerAliveInterval=15"
                "-o"
                "ServerAliveCountMax=2"
                "-o"
                "ClearAllForwardings=yes"
                remoteHost
                "/etc/profiles/per-user/${config.home.username}/bin/browse"
                "mcp"
              ];
              description = "Control the browser paired with ${remoteHost} over SSH";
              exposure = "direct";
              timeout = 900;
            };
          }) config.programs.browse.remoteHosts
        );
      in
      {
        options.programs.browse.remoteHosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Remote hosts whose local Browse MCP servers are available over SSH.";
        };
        config = {
          assertions = [
            {
              assertion = !builtins.elem hostName config.programs.browse.remoteHosts;
              message = "programs.browse.remoteHosts must not contain the local host ${hostName}";
            }
            {
              assertion =
                builtins.length config.programs.browse.remoteHosts
                == builtins.length (lib.unique config.programs.browse.remoteHosts);
              message = "programs.browse.remoteHosts must not contain duplicate hosts";
            }
          ];
          home.packages = [ browse ];
          wayland.windowManager.hyprland.extraConfig = ''
            hl.on("hyprland.start", function()
              hl.exec_cmd("${lib.getExe config.programs.chromium.package}", {
                workspace = "special:browse silent",
                no_initial_focus = true
              })
            end)
          '';
          programs = {
            chromium = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
              enable = true;
              extensions = [ extensionId ];
            };
            google-chrome = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
              enable = true;
              package = null;
              extensions = [ extensionId ];
            };
            mcp.servers = {
              browse = {
                command = lib.getExe browse;
                args = [ "mcp" ];
                env.OPENCODE_BROWSER_HYPRLAND_HANDOFF_WORKSPACE = "browse";
                description = "Control the browser paired with the local host, including human handoffs";
                exposure = "direct";
                timeout = 900;
              };
            }
            // remoteBrowseServers;
          };
        };
      };
  };
}
