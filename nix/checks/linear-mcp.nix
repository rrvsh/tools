{ config, lib, ... }:
let
  auto = config.flake.darwinConfigurations.auto.config;
  mercury = config.flake.nixosConfigurations.mercury.config;
  nemesis = config.flake.nixosConfigurations.nemesis.config;
in
{
  perSystem =
    { pkgs, system, ... }:
    lib.mkIf (system == "x86_64-linux") (
      let
        hermesActivation = pkgs.writeText "mercury-hermes-activation" ''
          ${mercury.system.activationScripts.hermes-agent-setup.text}
        '';
        hermesBin = builtins.elemAt (lib.splitString " " mercury.systemd.services.hermes-agent.serviceConfig.ExecStart) 0;
        piConfig = nemesis.home-manager.users.rafiq.xdg.configFile."mcp/mcp.json".source;
        piSettings =
          nemesis.home-manager.users.rafiq.home.file."/home/rafiq/.pi/agent/settings.json".source;
        sharedServers = pkgs.writeText "auto-shared-mcp-servers.json" (
          builtins.toJSON auto.home-manager.users.binmohm.programs.mcp.servers
        );
      in
      {
        checks.linear-mcp =
          pkgs.runCommand "linear-mcp-check"
            {
              nativeBuildInputs = [ pkgs.jq ];
            }
            ''
              set -euo pipefail

              jq -e '
                .mcpServers.linear == {
                  "url": "https://mcp.linear.app/mcp",
                  "auth": "oauth",
                  "lifecycle": "lazy",
                  "directTools": false
                }
              ' ${piConfig} >/dev/null

              hermes_config="$(grep -oEm1 '/nix/store/[a-z0-9]+-hermes-config\.yaml' ${hermesActivation})"
              jq -e '
                .mcp_servers.linear == {
                  "url": "https://mcp.linear.app/mcp",
                  "auth": "oauth",
                  "sampling": { "enabled": false }
                }
              ' "$hermes_config" >/dev/null

              jq -e '
                .["atlassian-mcp"].url == "https://mcp.atlassian.com/v1/mcp"
                and .linear.url == "https://mcp.linear.app/mcp"
              ' ${sharedServers} >/dev/null
              jq -e '.packages | index("npm:pi-mcp-adapter") != null' ${piSettings} >/dev/null

              ${hermesBin} mcp login --help | grep -F 'usage: hermes mcp login' >/dev/null
              export HERMES_HOME="$TMPDIR/hermes"
              mkdir -p "$HERMES_HOME"
              cp "$hermes_config" "$HERMES_HOME/config.yaml"
              ${hermesBin} mcp list | grep -F 'linear' >/dev/null
              test ! -e "$HERMES_HOME/mcp-tokens"

              touch "$out"
            '';
      }
    );
}
