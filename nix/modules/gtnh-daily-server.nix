{ inputs, ... }:
{
  config.flake.modules.nixos.gtnh-daily-server =
    { pkgs, ... }:
    let
      user = "gtnh-daily";
      group = user;
      unit = "gtnh-daily-server";
      rootDir = "/var/lib/gtnh-daily";
      serverDir = "${rootDir}/server";
      backupDir = "${rootDir}/backups";
      cacheDir = "${rootDir}/cache";
      configDir = "${rootDir}/config";
      stdin = "/run/${unit}.stdin";
      lockFile = "/run/gtnh-daily-update.lock";
      manifestUrl = "https://raw.githubusercontent.com/GTNewHorizons/DreamAssemblerXXL/master/releases/manifests/daily.json";
      currentManifest = "${rootDir}/current-manifest.json";
      currentManifestHash = "${rootDir}/current-manifest.sha256";
      port = 25566;
      java = pkgs.jdk25_headless;
      updater = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gtnh-daily-updater;
      tar = "${pkgs.gnutar}/bin/tar --use-compress-program=${pkgs.zstd}/bin/zstd --xattrs --acls";
      updaterEnv = "HOME=${rootDir} XDG_CACHE_HOME=${cacheDir} XDG_CONFIG_HOME=${configDir} PATH=${pkgs.git}/bin";
      stopScript = pkgs.writeShellScript "${unit}-stop" ''
        set -euo pipefail
        if [ -p ${stdin} ]; then
          echo stop > ${stdin} || true
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
      backupScript = pkgs.writeShellScript "gtnh-daily-backup" ''
        set -euo pipefail
        if [ ! -d ${serverDir} ]; then
          echo "${serverDir} does not exist" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/mkdir -p ${backupDir}
        ts="$(${pkgs.coreutils}/bin/date -u +%Y%m%d-%H%M%S)"
        dest="${backupDir}/pre-update-$ts.tar.zst"
        ${tar} -C ${rootDir} -cf "$dest" server
        ${pkgs.coreutils}/bin/chown ${user}:${group} "$dest"
        ${pkgs.coreutils}/bin/ln -sfn "$(${pkgs.coreutils}/bin/basename "$dest")" ${backupDir}/latest.tar.zst
        echo "$dest"
      '';
      updateScript = pkgs.writeShellScript "gtnh-daily-update" ''
        set -euo pipefail
        exec 9>${lockFile}
        ${pkgs.util-linux}/bin/flock -n 9
        manifest="$(${pkgs.coreutils}/bin/mktemp --tmpdir gtnh-daily-manifest.XXXXXX.json)"
        cleanup() {
          ${pkgs.coreutils}/bin/rm -f "$manifest"
        }
        trap cleanup EXIT
        ${pkgs.curl}/bin/curl --fail --location --silent --show-error ${manifestUrl} --output "$manifest"
        ${pkgs.coreutils}/bin/chmod 0644 "$manifest"
        was_active=0
        if ${pkgs.systemd}/bin/systemctl is-active --quiet ${unit}.service; then
          was_active=1
        fi
        ${pkgs.systemd}/bin/systemctl stop ${unit}.service || true
        restart_if_needed() {
          if [ "$was_active" = 1 ]; then
            ${pkgs.systemd}/bin/systemctl start ${unit}.service || true
          fi
        }
        finish() {
          cleanup
          restart_if_needed
        }
        trap finish EXIT
        ${backupScript}
        ${pkgs.util-linux}/bin/runuser -u ${user} -- \
          env ${updaterEnv} \
          ${updater}/bin/gtnh-daily-updater update --instance-dir ${serverDir} --manifest-file "$manifest"
        ${pkgs.coreutils}/bin/install -o ${user} -g ${group} -m 0644 "$manifest" ${currentManifest}
        ${pkgs.coreutils}/bin/sha256sum ${currentManifest} > ${currentManifestHash}
        ${pkgs.coreutils}/bin/chown ${user}:${group} ${currentManifestHash}
        restart_if_needed
        cleanup
        trap - EXIT
      '';
      rollback = pkgs.writeShellScriptBin "gtnh-daily-rollback" ''
        set -euo pipefail
        if [ "$(${pkgs.coreutils}/bin/id -u)" != 0 ]; then
          echo "Run as root: sudo gtnh-daily-rollback [backup.tar.zst]" >&2
          exit 1
        fi
        backup="''${1:-}"
        if [ -z "$backup" ]; then
          backup="$(${pkgs.findutils}/bin/find ${backupDir} -maxdepth 1 -type f -name 'pre-update-*.tar.zst' -printf '%T@ %p\n' | ${pkgs.coreutils}/bin/sort -nr | ${pkgs.gawk}/bin/awk 'NR == 1 { print $2 }')"
        fi
        if [ -z "$backup" ] || [ ! -f "$backup" ]; then
          echo "No backup found under ${backupDir}" >&2
          exit 1
        fi
        ts="$(${pkgs.coreutils}/bin/date -u +%Y%m%d-%H%M%S)"
        ${pkgs.systemd}/bin/systemctl stop ${unit}.service || true
        if [ -e ${serverDir} ]; then
          ${pkgs.coreutils}/bin/mv ${serverDir} ${rootDir}/server.rollback-$ts
        fi
        ${tar} -C ${rootDir} -xf "$backup"
        ${pkgs.coreutils}/bin/chown -R ${user}:${group} ${serverDir}
        ${pkgs.systemd}/bin/systemctl start ${unit}.service
        echo "Rolled back ${serverDir} from $backup"
      '';
    in
    {
      users = {
        users.${user} = {
          description = "GT New Horizons daily server user";
          isSystemUser = true;
          inherit group;
          home = rootDir;
          createHome = true;
        };
        groups.${group} = { };
      };
      environment.systemPackages = [ rollback ];
      systemd = {
        tmpfiles.rules = [
          "d ${rootDir} 0755 ${user} ${group} -"
          "d ${serverDir} 0750 ${user} ${group} -"
          "d ${backupDir} 0750 ${user} ${group} -"
          "d ${cacheDir} 0750 ${user} ${group} -"
          "d ${configDir} 0750 ${user} ${group} -"
        ];
        sockets.${unit} = {
          bindsTo = [ "${unit}.service" ];
          socketConfig = {
            ListenFIFO = stdin;
            SocketMode = "0660";
            SocketUser = user;
            SocketGroup = group;
            RemoveOnStop = true;
            FlushPending = true;
          };
        };
        services = {
          ${unit} = {
            description = "GT New Horizons daily server";
            wantedBy = [ "multi-user.target" ];
            requires = [ "${unit}.socket" ];
            after = [
              "network-online.target"
              "${unit}.socket"
            ];
            wants = [ "network-online.target" ];
            unitConfig.ConditionPathExists = [
              "${serverDir}/java9args.txt"
              "${serverDir}/lwjgl3ify-forgePatches.jar"
            ];
            path = [
              java
              pkgs.bash
              pkgs.coreutils
              pkgs.gnused
            ];
            preStart = ''
              if [ -f server.properties ]; then
                if grep -q '^server-port=' server.properties; then
                  sed -i 's/^server-port=.*/server-port=${toString port}/' server.properties
                else
                  printf '\nserver-port=${toString port}\n' >> server.properties
                fi
              fi
            '';
            serviceConfig = {
              User = user;
              Group = group;
              WorkingDirectory = serverDir;
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
              ReadWritePaths = [ rootDir ];
              ProtectHome = true;
            };
          };
          gtnh-daily-update = {
            description = "Update GT New Horizons daily server";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            unitConfig.ConditionPathExists = [ "${serverDir}/.gtnh-daily-updater.json" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = updateScript;
            };
          };
        };
        timers.gtnh-daily-update = {
          description = "Update GT New Horizons daily server on schedule";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 05:00:00";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
      networking.firewall = {
        allowedTCPPorts = [ port ];
        allowedUDPPorts = [ port ];
      };
    };
}
