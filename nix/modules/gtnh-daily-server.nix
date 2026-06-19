# NixOS module for the reproducible GTNH Daily dedicated server.
# Plain-language docs live in docs/gtnh-daily/; implementation-notes.md explains the Nix,
# shell, Python, systemd, manifest, and backup choices in this file.
# This module defines identity, directories, bootstrap, update, rollback, service sandboxing,
# stdin control, firewall, and declared updater extras/excludes while intentionally excluding
# mutable world data from the declarative guarantee.
{ inputs, ... }:
{
  config.flake.modules.nixos.gtnh-daily-server =
    { pkgs, ... }:
    let
      # Dedicated Linux user/group isolates Daily from the stable `/srv/gtnh` server.
      user = "gtnh-daily";
      group = user;
      unit = "gtnh-daily-server";
      # Root must be traversable so clients can SSH-read the published manifest files.
      rootDir = "/var/lib/gtnh-daily";
      serverDir = "${rootDir}/server";
      backupDir = "${rootDir}/backups";
      cacheDir = "${rootDir}/cache";
      configDir = "${rootDir}/config";
      stdin = "/run/${unit}.stdin";
      lockFile = "/run/gtnh-daily-update.lock";
      # Latest Daily manifest URL used for server bootstrap/update discovery.
      manifestUrl = "https://raw.githubusercontent.com/GTNewHorizons/DreamAssemblerXXL/master/releases/manifests/daily.json";
      currentManifest = "${rootDir}/current-manifest.json";
      currentManifestHash = "${rootDir}/current-manifest.sha256";
      # Daily listens on 25566 so it can coexist with the stable server on 25565.
      port = 25566;
      java = pkgs.jdk25_headless;
      updater = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gtnh-daily-updater;
      tar = "${pkgs.gnutar}/bin/tar --use-compress-program=${pkgs.zstd}/bin/zstd --xattrs --acls";
      updaterEnv = "HOME=${rootDir} XDG_CACHE_HOME=${cacheDir} XDG_CONFIG_HOME=${configDir} PATH=${pkgs.git}/bin";
      # Desired server updater policy. These fields are owned by Nix: manual edits to
      # `exclude_mods`/`extra_mods` are overwritten unless they are added here.
      serverExcludeMods = [ "JourneyMap Server" ];
      serverExtraMods = {
        GTNH-Web-Map = {
          source = "github:GTNewHorizons/GTNH-Web-Map";
          side = "SERVER";
          match = "^gtnh-web-map-.*[0-9]\\.jar$";
        };
        MineMenu = {
          source = "modrinth:mine-menu/HNivj4HD";
          side = "SERVER";
        };
      };
      serverStateJson = pkgs.writeText "gtnh-daily-server-state.json" (
        builtins.toJSON {
          exclude_mods = serverExcludeMods;
          extra_mods = serverExtraMods;
        }
      );
      # Reconcile only declared updater-state knobs; leave scanned mods, world data, logs, and configs alone.
      reconcileState = pkgs.writeShellScript "gtnh-daily-server-reconcile-state" ''
                # Fail on any JSON/IO error so services do not run with partially-written updater state.
                set -euo pipefail
                state=${serverDir}/.gtnh-daily-updater.json
                [ -f "$state" ] || exit 0
                ${pkgs.python3}/bin/python3 - "$state" ${serverStateJson} <<'PY'
        import json, sys
        state_path, desired_path = sys.argv[1:]
        with open(state_path) as f:
            state = json.load(f)
        with open(desired_path) as f:
            desired = json.load(f)
        changed = False
        if state.get("exclude_mods") != desired["exclude_mods"]:
            state["exclude_mods"] = desired["exclude_mods"]
            changed = True
        if state.get("extra_mods") != desired["extra_mods"]:
            state["extra_mods"] = desired["extra_mods"]
            changed = True
        if changed:
            with open(state_path, "w") as f:
                json.dump(state, f, indent=2)
                f.write("\n")
        PY
                ${pkgs.coreutils}/bin/chown ${user}:${group} "$state"
      '';
      # Bootstrap creates a missing server from Daily artifacts and prepares updater/EULA state.
      # It does not overwrite an existing bootstrapped server or delete World/.
      bootstrapScript = pkgs.writeShellScript "gtnh-daily-bootstrap" ''
                # Stop immediately on errors because a half-bootstrapped modded server is unsafe to start.
                set -euo pipefail
                ${pkgs.coreutils}/bin/install -d -o ${user} -g ${group} -m 0755 ${rootDir}
                ${pkgs.coreutils}/bin/install -d -o ${user} -g ${group} -m 0750 ${serverDir} ${backupDir} ${cacheDir} ${configDir}
                manifest="${currentManifest}"
                # Fetch the latest published manifest if the server has not yet published an applied manifest.
                if [ ! -s "$manifest" ]; then
                  tmp_manifest="$(${pkgs.coreutils}/bin/mktemp --tmpdir gtnh-daily-bootstrap-manifest.XXXXXX.json)"
                  ${pkgs.curl}/bin/curl --fail --location --silent --show-error ${manifestUrl} --output "$tmp_manifest"
                  ${pkgs.coreutils}/bin/install -o ${user} -g ${group} -m 0644 "$tmp_manifest" "$manifest"
                  ${pkgs.coreutils}/bin/sha256sum "$manifest" > ${currentManifestHash}
                  ${pkgs.coreutils}/bin/chown ${user}:${group} ${currentManifestHash}
                  ${pkgs.coreutils}/bin/rm -f "$tmp_manifest"
                fi
                # Download/extract a server artifact only when core launch files are absent.
                if [ ! -e ${serverDir}/java9args.txt ] || [ ! -e ${serverDir}/lwjgl3ify-forgePatches.jar ]; then
                  tmp="$(${pkgs.coreutils}/bin/mktemp -d --tmpdir gtnh-daily-bootstrap.XXXXXX)"
                  cleanup() { ${pkgs.coreutils}/bin/rm -rf "$tmp"; }
                  trap cleanup EXIT
                  auth=()
                  if [ -n "''${GITHUB_TOKEN:-}" ]; then
                    auth=(-H "Authorization: Bearer ''${GITHUB_TOKEN}")
                  fi
                  runs_url='https://api.github.com/repos/GTNewHorizons/DreamAssemblerXXL/actions/workflows/daily-modpack-build.yml/runs?status=success&per_page=20'
                  ${pkgs.curl}/bin/curl --fail --location --silent --show-error "''${auth[@]}" "$runs_url" -o "$tmp/runs.json"
                  ${pkgs.python3}/bin/python3 - "$tmp/runs.json" > "$tmp/run_ids" <<'PY'
        import json, sys
        for run in json.load(open(sys.argv[1])).get("workflow_runs", []):
            print(run["id"])
        PY
                  server_url=""
                  manifest_url=""
                  while read -r run_id; do
                    [ -n "$run_id" ] || continue
                    ${pkgs.curl}/bin/curl --fail --location --silent --show-error "''${auth[@]}" "https://api.github.com/repos/GTNewHorizons/DreamAssemblerXXL/actions/runs/$run_id/artifacts" -o "$tmp/artifacts.json"
                    eval "$(${pkgs.python3}/bin/python3 - "$tmp/artifacts.json" <<'PY'
        import json, shlex, sys
        server = manifest = ""
        for artifact in json.load(open(sys.argv[1])).get("artifacts", []):
            if artifact.get("expired"):
                continue
            name = artifact.get("name", "")
            if "server-java17-25.zip" in name:
                server = artifact["archive_download_url"]
            elif name.startswith("gtnh-daily-") and name.endswith("-manifest.json"):
                manifest = artifact["archive_download_url"]
        print("server_url=" + shlex.quote(server))
        print("manifest_url=" + shlex.quote(manifest))
        PY
        )"
                    if [ -n "$server_url" ] && [ -n "$manifest_url" ]; then
                      break
                    fi
                  done < "$tmp/run_ids"
                  if [ -z "$server_url" ] || [ -z "$manifest_url" ]; then
                    echo "Could not find non-expired GTNH Daily server artifacts. Set GITHUB_TOKEN if GitHub requires authentication." >&2
                    exit 1
                  fi
                  ${pkgs.curl}/bin/curl --fail --location --silent --show-error "''${auth[@]}" "$server_url" -o "$tmp/server-artifact.zip"
                  ${pkgs.curl}/bin/curl --fail --location --silent --show-error "''${auth[@]}" "$manifest_url" -o "$tmp/manifest-artifact.zip"
                  ${pkgs.unzip}/bin/unzip -q "$tmp/server-artifact.zip" -d "$tmp/server"
                  ${pkgs.unzip}/bin/unzip -q "$tmp/manifest-artifact.zip" -d "$tmp/manifest"
                  ${pkgs.coreutils}/bin/cp -a "$tmp/server/." ${serverDir}/
                  found_manifest="$(${pkgs.findutils}/bin/find "$tmp/manifest" -type f -name '*.json' | ${pkgs.coreutils}/bin/head -n1)"
                  if [ -n "$found_manifest" ]; then
                    ${pkgs.coreutils}/bin/install -o ${user} -g ${group} -m 0644 "$found_manifest" "$manifest"
                    ${pkgs.coreutils}/bin/sha256sum "$manifest" > ${currentManifestHash}
                    ${pkgs.coreutils}/bin/chown ${user}:${group} ${currentManifestHash}
                  fi
                  ${pkgs.coreutils}/bin/chown -R ${user}:${group} ${serverDir}
                fi
                # Initialize updater state after files exist; init scans mods and config baselines.
                if [ ! -f ${serverDir}/.gtnh-daily-updater.json ]; then
                  config_version="$(${pkgs.python3}/bin/python3 - ${currentManifest} <<'PY'
        import json, sys
        print(json.load(open(sys.argv[1]))["config"])
        PY
        )"
                  ${pkgs.util-linux}/bin/runuser -u ${user} -- env ${updaterEnv} ${updater}/bin/gtnh-daily-updater init --instance-dir ${serverDir} --side server --config "$config_version"
                fi
                ${reconcileState}
                if [ -f ${serverDir}/eula.txt ]; then
                  ${pkgs.gnused}/bin/sed -i 's/^eula=false/eula=true/' ${serverDir}/eula.txt
                else
                  printf 'eula=true\n' > ${serverDir}/eula.txt
                fi
                ${pkgs.coreutils}/bin/chown ${user}:${group} ${serverDir}/eula.txt
      '';
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
      # Update applies a pinned manifest, backs up first, and republishes the exact applied manifest for clients.
      updateScript = pkgs.writeShellScript "gtnh-daily-update" ''
        # Treat every failure as fatal so backup/update/publish steps do not silently diverge.
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
      # Rollback restores the latest or selected pre-update backup and restarts the Daily server.
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
      # System user/group declaration makes ownership reproducible across rebuilds.
      users = {
        users.${user} = {
          description = "GT New Horizons daily server user";
          isSystemUser = true;
          inherit group;
          home = rootDir;
          homeMode = "0755";
          createHome = true;
        };
        groups.${group} = { };
      };
      environment.systemPackages = [ rollback ];
      systemd = {
        # Tmpfiles enforces directory existence/modes without overwriting mutable contents.
        tmpfiles.rules = [
          "d ${rootDir} 0755 ${user} ${group} -"
          "d ${serverDir} 0750 ${user} ${group} -"
          "d ${backupDir} 0750 ${user} ${group} -"
          "d ${cacheDir} 0750 ${user} ${group} -"
          "d ${configDir} 0750 ${user} ${group} -"
        ];
        # FIFO socket provides a safe stdin path for sending Minecraft console commands via systemd.
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
          # Bootstrap is a oneshot dependency of the main server and is safe to rerun.
          gtnh-daily-bootstrap = {
            description = "Bootstrap GT New Horizons daily server declaratively";
            wantedBy = [ "multi-user.target" ];
            before = [ "${unit}.service" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = bootstrapScript;
            };
          };
          # Main dedicated server JVM service.
          ${unit} = {
            description = "GT New Horizons daily server";
            wantedBy = [ "multi-user.target" ];
            requires = [
              "${unit}.socket"
              "gtnh-daily-bootstrap.service"
            ];
            after = [
              "network-online.target"
              "${unit}.socket"
              "gtnh-daily-bootstrap.service"
            ];
            wants = [
              "network-online.target"
              "gtnh-daily-bootstrap.service"
            ];
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
                  -Dfml.queryResult=confirm \
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
          # Scheduled updater service; it reconciles desired updater state before applying Daily updates.
          gtnh-daily-update = {
            description = "Update GT New Horizons daily server";
            after = [
              "network-online.target"
              "gtnh-daily-bootstrap.service"
            ];
            wants = [
              "network-online.target"
              "gtnh-daily-bootstrap.service"
            ];
            unitConfig.ConditionPathExists = [ "${serverDir}/.gtnh-daily-updater.json" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStartPre = reconcileState;
              ExecStart = updateScript;
            };
          };
        };
        # Timer schedules Daily updates around 05:00 with jitter and catch-up behavior.
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
      # Open only the Minecraft Daily port here; web-map exposure is handled separately if desired.
      networking.firewall = {
        allowedTCPPorts = [ port ];
        allowedUDPPorts = [ port ];
      };
    };
}
