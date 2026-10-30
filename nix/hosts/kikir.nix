{
  config,
  lib,
  primaryUsers,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake.hosts.darwin.kikir = {
    hostPlatform = "aarch64-darwin";
    primaryUser = primaryUsers.rafiq;
    profiles = [
      "graphical"
      "development"
    ];
    modules = [
      cfg.modules.darwin.user-primary
      cfg.modules.darwin.agent-browser-shared
      cfg.modules.darwin.aerospace
      (
        { pkgs, ... }:
        {
          users.users.rafiq.uid = lib.mkForce 502;
          home-manager.sharedModules = [
            {
              home = {
                file.".testcontainers.properties".text =
                  "docker.host=unix:///Users/rafiq/.colima/default/docker.sock\n";
                sessionVariables.TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";
              };
            }
            {
              programs.mcp.servers = {
                atlassian = {
                  url = "https://mcp.atlassian.com/v2/mcp";
                  exposure = "codemode";
                };
                datadog = {
                  url = "https://mcp.us5.datadoghq.com/v1/mcp";
                  exposure = "codemode";
                };
                figma = {
                  url = "https://mcp.figma.com/mcp";
                  exposure = "codemode";
                  # Figma currently rejects clients outside its MCP catalog.
                  oauth.clientName = "Claude Code";
                };
                slack = {
                  url = "https://mcp.slack.com/mcp";
                  exposure = "codemode";
                  oauth = {
                    clientId = "556588767717.12269619509622";
                    callbackPort = 3118;
                  };
                };
              };
              home.packages = with pkgs; [
                awscli2
                kubectl
                colima
                docker-client
                goose
                nodejs_24
                (writeShellApplication {
                  name = "awslocal";
                  runtimeInputs = [ awscli2 ];
                  text = ''
                    export AWS_ACCESS_KEY_ID="''${AWS_ACCESS_KEY_ID:-test}"
                    export AWS_SECRET_ACCESS_KEY="''${AWS_SECRET_ACCESS_KEY:-test}"
                    export AWS_DEFAULT_REGION="''${AWS_DEFAULT_REGION:-us-east-1}"
                    exec aws --endpoint-url="''${AWS_ENDPOINT_URL:-http://localhost:4566}" "$@"
                  '';
                })
                (writeShellApplication {
                  name = "pnpm";
                  runtimeInputs = [ nodejs_24 ];
                  text = ''
                    exec corepack pnpm "$@"
                  '';
                })
              ];
              programs.fish.plugins = [
                {
                  name = "nvm";
                  inherit (pkgs.fishPlugins.nvm) src;
                }
              ];
            }
          ];
        }
      )
    ];
  };
}
