{
  config.flake.modules.nixos.gtnh-server =
    { pkgs, ... }:
    let
      gtnhDir = "/srv/gtnh";
      java = pkgs.jdk25_headless;
      stopScript = pkgs.writeShellScript "gtnh-stop" ''
        set -euo pipefail

        if [ -p /run/gtnh-server.stdin ]; then
          echo "stop" > /run/gtnh-server.stdin || true
        fi

        timeout=120
        while kill -0 "$1" 2>/dev/null && [ "$timeout" -gt 0 ]; do
          sleep 1
          timeout=$((timeout - 1))
        done

        if kill -0 "$1" 2>/dev/null; then
          kill -TERM "$1"
        fi
      '';
    in
    {
      users = {
        users.gtnh = {
          description = "GT New Horizons server user";
          isSystemUser = true;
          group = "gtnh";
          home = gtnhDir;
          createHome = true;
        };
        groups.gtnh = { };
      };
      systemd = {
        tmpfiles.rules = [ "d ${gtnhDir} 0750 gtnh gtnh -" ];
        sockets.gtnh-server = {
          bindsTo = [ "gtnh-server.service" ];
          socketConfig = {
            ListenFIFO = "/run/gtnh-server.stdin";
            SocketMode = "0660";
            SocketUser = "gtnh";
            SocketGroup = "gtnh";
            RemoveOnStop = true;
            FlushPending = true;
          };
        };
        services.gtnh-server = {
          description = "GT New Horizons 2.8.4 Server";
          wantedBy = [ "multi-user.target" ];
          requires = [ "gtnh-server.socket" ];
          after = [
            "network-online.target"
            "gtnh-server.socket"
          ];
          wants = [ "network-online.target" ];
          unitConfig.ConditionPathExists = [
            "${gtnhDir}/java9args.txt"
            "${gtnhDir}/lwjgl3ify-forgePatches.jar"
          ];
          path = [
            java
            pkgs.bash
            pkgs.coreutils
          ];
          serviceConfig = {
            User = "gtnh";
            Group = "gtnh";
            WorkingDirectory = gtnhDir;
            Restart = "on-failure";
            RestartSec = "30s";
            SuccessExitStatus = "0 143";
            StandardInput = "socket";
            StandardOutput = "journal";
            StandardError = "journal";
            ExecStart = ''
              ${java}/bin/java \
                -Xms6G \
                -Xmx10G \
                -XX:+UseZGC \
                -Dfml.readTimeout=180 \
                @java9args.txt \
                -jar lwjgl3ify-forgePatches.jar \
                nogui
            '';
            ExecStop = "${stopScript} $MAINPID";
            UMask = "0027";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ReadWritePaths = [ gtnhDir ];
            ProtectHome = true;
          };
        };
      };
      networking.firewall = {
        allowedTCPPorts = [ 25565 ];
        allowedUDPPorts = [ 25565 ];
      };
    };
}
