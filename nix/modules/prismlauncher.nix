# Prism Launcher and GTNH Daily client module.
# Plain-language docs live in docs/gtnh-daily/; implementation-notes.md explains the Nix,
# shell, Python, systemd-user, manifest, resource-pack, and shader-pack choices in this file.
# Every declaration below exists to make the launcher, client updater state, resource packs,
# shader packs, desktop entries, and user sync timer reproducible after a wipe/rebuild.
{ config, inputs, ... }:
let
  # Flake-parts module namespace used to wire platform modules to the Home Manager module.
  cfg = config.flake;
  # Shared OS wrapper: NixOS/Darwin import this and receive the Home Manager Prism module.
  osModule = {
    # Inject Prism configuration into Home Manager rather than duplicating it per host OS.
    home-manager.sharedModules = [ cfg.modules.homeManager.prismlauncher ];
  };
in
{
  config.flake.modules = {
    darwin.prismlauncher = osModule;
    nixos.prismlauncher = osModule;
    homeManager.prismlauncher =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        # Exact Prism instance name used by launcher metadata, desktop entries, and sync scripts.
        gtnhDailyInstanceName = "GT New Horizons (Daily)";
        gtnhDailyInstanceDir = "${config.home.homeDirectory}/.local/share/PrismLauncher/instances/${gtnhDailyInstanceName}";
        # Keep only the newest successful pre-sync backups; each archive is about 2 GiB.
        gtnhDailyBackupRetentionCount = 5;
        # Repo-built updater includes our local manifest pinning patch.
        gtnhDailyUpdater = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gtnh-daily-updater;
        # Resource/shader pack artifacts are downloaded at bootstrap time instead of committed to git.
        # Updating a pack means changing its URL/name/hash together; bootstrap verifies the hash before use.
        clientAssetsJson = pkgs.writeText "gtnh-daily-client-assets.json" (
          builtins.toJSON {
            resourcePacks = [
              {
                name = "AE2-Dark-Mode.v.1.18.zip";
                url = "https://github.com/Ranzuu/AE2-Dark-Mode/releases/download/v.1.18/AE2-Dark-Mode.v.1.18.zip";
                sha256 = "d8521075c02fecaad6b11f6c9766da7b195ae5d24497da280f755da0a52e23b0";
                extractDir = "AE2-Dark-Mode.v.1.18";
                stripRoot = false;
              }
              {
                name = "Shadow.UI.v5.30-Modernity.version.zip";
                url = "https://github.com/Ranzuu/Shadow-UI/releases/download/v2.9.X/v5.30/Shadow.UI.v5.30-Modernity.version.zip";
                sha256 = "a1a3dd250f42a3ce4c904cb1fef1f6bec313c23869e6591be1fd957a10cc9655";
                extractDir = "shadowui";
                stripRoot = false;
              }
              {
                name = "Modernity-GTNH-main.zip";
                url = "https://github.com/ModernityGTNH/Modernity-GTNH/archive/c3cd734cf5b912debdbcf75b9a88509d19f8fdfa.zip";
                sha256 = "d629e5b6022b208ef3d5707ad95712a7e4d5ff516e5151786fae051d232e6213";
                extractDir = "Modernity-GTNH-main";
                stripRoot = true;
              }
            ];
            shaderPacks = [
              {
                name = "ComplementaryReimagined_r5.8.1.zip";
                url = "https://cdn.modrinth.com/data/HVnmMxH1/versions/yCCduG44/ComplementaryReimagined_r5.8.1.zip";
                sha256 = "3f1cd389e717b2e62f58edff222059b9c60de71b14bb49b517eb58318ce35b15";
              }
              {
                name = "ComplementaryUnbound_r5.8.1.zip";
                url = "https://cdn.modrinth.com/data/R6NEzAwj/versions/VMHXIk50/ComplementaryUnbound_r5.8.1.zip";
                sha256 = "bb89b1fc54687d4147a837fb2e3c3f7261a13bee51819761e9b6a91cb7915965";
              }
            ];
          }
        );
        # Desired client updater policy. This field is owned by Nix: manual edits to
        # `extra_mods` are overwritten unless they are added here.
        clientStateJson = pkgs.writeText "gtnh-daily-client-state.json" (
          builtins.toJSON {
            extra_mods = {
              JourneyMap = {
                source = "github:TeamJM/journeymap-legacy";
                side = "CLIENT";
                match = "unlimited\\.jar$";
              };
              MineMenu = {
                source = "modrinth:mine-menu/HNivj4HD";
                side = "CLIENT";
              };
            };
          }
        );
        # Bootstrap creates/repairs the Prism instance, updater state, packs, and selected resource packs.
        # It refuses to run while Prism/Minecraft appears active to avoid changing files under a running game.
        gtnhDailyClientBootstrap = pkgs.writeShellScriptBin "gtnh-daily-client-bootstrap" ''
                    set -euo pipefail

                    server="''${GTNH_DAILY_SERVER:-nemesis}"
                    remote_manifest="/var/lib/gtnh-daily/current-manifest.json"
                    remote_hash="/var/lib/gtnh-daily/current-manifest.sha256"
                    instance_dir="${gtnhDailyInstanceDir}"
                    game_dir="$instance_dir/.minecraft"
                    state_file="$instance_dir/.gtnh-daily-updater.json"
                    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/gtnh-daily-client-sync"
                    local_manifest="$cache_dir/current-manifest.json"
                    local_hash="$cache_dir/current-manifest.sha256"

                    # Create local cache and Prism instance parent directories before network/bootstrap work.
                    mkdir -p "$cache_dir" "$HOME/.local/share/PrismLauncher/instances"
                    if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f 'prismlauncher|net\.minecraft|minecraft|lwjgl3ify' >/dev/null; then
                      echo "Prism or Minecraft appears to be running; refusing to bootstrap the client instance." >&2
                      exit 1
                    fi
                    fetched_hash="$(${pkgs.openssh}/bin/ssh -o BatchMode=yes "$server" "cat '$remote_hash'")"
                    ${pkgs.openssh}/bin/scp -q -o BatchMode=yes "$server:$remote_manifest" "$local_manifest"
                    expected_hash="$(printf '%s\n' "$fetched_hash" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
                    actual_hash="$(${pkgs.coreutils}/bin/sha256sum "$local_manifest" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
                    if [ "$expected_hash" != "$actual_hash" ]; then
                      echo "Manifest hash mismatch: expected $expected_hash, got $actual_hash" >&2
                      exit 1
                    fi

                    # Only download/extract the Prism artifact when the game directory is missing.
                    if [ ! -d "$game_dir" ]; then
                      tmp="$(${pkgs.coreutils}/bin/mktemp -d --tmpdir gtnh-daily-client-bootstrap.XXXXXX)"
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
                      client_url=""
                      while read -r run_id; do
                        [ -n "$run_id" ] || continue
                        ${pkgs.curl}/bin/curl --fail --location --silent --show-error "''${auth[@]}" "https://api.github.com/repos/GTNewHorizons/DreamAssemblerXXL/actions/runs/$run_id/artifacts" -o "$tmp/artifacts.json"
                        client_url="$(${pkgs.python3}/bin/python3 - "$tmp/artifacts.json" <<'PY'
          import json, sys
          for artifact in json.load(open(sys.argv[1])).get("artifacts", []):
              name = artifact.get("name", "")
              if not artifact.get("expired") and "mmcprism-java17-25.zip" in name:
                  print(artifact["archive_download_url"])
                  break
          PY
          )"
                        [ -n "$client_url" ] && break
                      done < "$tmp/run_ids"
                      if [ -z "$client_url" ]; then
                        echo "Could not find non-expired GTNH Daily Prism artifacts. Set GITHUB_TOKEN if GitHub requires authentication." >&2
                        exit 1
                      fi
                      ${pkgs.curl}/bin/curl --fail --location --silent --show-error "''${auth[@]}" "$client_url" -o "$tmp/client-artifact.zip"
                      ${pkgs.unzip}/bin/unzip -q "$tmp/client-artifact.zip" -d "$tmp/client"
                      ${pkgs.coreutils}/bin/mkdir -p "$instance_dir"
                      ${pkgs.coreutils}/bin/cp -a "$tmp/client/." "$instance_dir/"
                    fi

                    config_version="$(${pkgs.python3}/bin/python3 - "$local_manifest" <<'PY'
          import json, sys
          print(json.load(open(sys.argv[1]))["config"])
          PY
          )"
                    # Initialize gtnh-daily-updater state only when missing; existing state is reconciled below.
                    if [ ! -f "$state_file" ]; then
                      PATH=${pkgs.git}/bin:$PATH ${gtnhDailyUpdater}/bin/gtnh-daily-updater init --instance-dir "$instance_dir" --side client --config "$config_version"
                    fi
                    ${pkgs.python3}/bin/python3 - "$state_file" ${clientStateJson} <<'PY'
          import json, sys
          state_path, desired_path = sys.argv[1:]
          state = json.load(open(state_path))
          desired = json.load(open(desired_path))
          changed = False
          if state.get("extra_mods") != desired["extra_mods"]:
              state["extra_mods"] = desired["extra_mods"]
              changed = True
          if changed:
              with open(state_path, "w") as f:
                  json.dump(state, f, indent=2)
                  f.write("\n")
          PY
                    # Ensure resource/shader directories exist, then fetch declared non-world client assets.
                    mkdir -p "$game_dir/resourcepacks" "$game_dir/shaderpacks"
                    ${pkgs.python3}/bin/python3 - ${clientAssetsJson} "$game_dir" <<'PY'
          import json, os, shutil, subprocess, sys, tempfile, zipfile
          assets_path, game_dir = sys.argv[1:]
          with open(assets_path) as f:
              assets = json.load(f)
          resourcepacks = os.path.join(game_dir, "resourcepacks")
          shaderpacks = os.path.join(game_dir, "shaderpacks")
          def sha256(path):
              out = subprocess.check_output(["${pkgs.coreutils}/bin/sha256sum", path], text=True)
              return out.split()[0]
          def download(url, dest, expected):
              if os.path.exists(dest) and sha256(dest) == expected:
                  return
              tmp = dest + ".tmp"
              subprocess.check_call(["${pkgs.curl}/bin/curl", "--fail", "--location", "--silent", "--show-error", url, "--output", tmp])
              actual = sha256(tmp)
              if actual != expected:
                  os.remove(tmp)
                  raise SystemExit(f"hash mismatch for {dest}: expected {expected}, got {actual}")
              os.replace(tmp, dest)
          def extract_resource(spec):
              dest = os.path.join(resourcepacks, spec["name"])
              download(spec["url"], dest, spec["sha256"])
              extract_dir = os.path.join(resourcepacks, spec["extractDir"])
              marker = extract_dir + ".sha256"
              if os.path.exists(extract_dir) and os.path.exists(marker) and open(marker).read().strip() == spec["sha256"]:
                  return
              shutil.rmtree(extract_dir, ignore_errors=True)
              with tempfile.TemporaryDirectory(dir=resourcepacks) as tmpdir:
                  with zipfile.ZipFile(dest) as zf:
                      zf.extractall(tmpdir)
                  if spec.get("stripRoot"):
                      entries = os.listdir(tmpdir)
                      if len(entries) != 1 or not os.path.isdir(os.path.join(tmpdir, entries[0])):
                          raise SystemExit(f"expected one top-level directory in {dest}")
                      shutil.move(os.path.join(tmpdir, entries[0]), extract_dir)
                  else:
                      os.makedirs(extract_dir, exist_ok=True)
                      for entry in os.listdir(tmpdir):
                          shutil.move(os.path.join(tmpdir, entry), os.path.join(extract_dir, entry))
              with open(marker, "w") as f:
                  f.write(spec["sha256"] + "\n")
          for spec in assets["resourcePacks"]:
              extract_resource(spec)
          for spec in assets["shaderPacks"]:
              download(spec["url"], os.path.join(shaderpacks, spec["name"]), spec["sha256"])
          with open(os.path.join(shaderpacks, "ComplementaryUnbound_r5.8.1.zip.txt"), "w") as f:
              f.write("LIGHT_COLOR_MULTS=true\nLIGHT_NIGHT_I=0.01\n")
          for root in (resourcepacks, shaderpacks, os.path.join(game_dir, ".gtnh-configs", "resourcepacks")):
              if os.path.exists(root):
                  for dirpath, dirnames, filenames in os.walk(root):
                      os.chmod(dirpath, 0o755)
                      for name in filenames:
                          try:
                              os.chmod(os.path.join(dirpath, name), 0o644)
                          except FileNotFoundError:
                              pass
          PY
                    if [ -f "$game_dir/options.txt" ]; then
                      ${pkgs.python3}/bin/python3 - "$game_dir/options.txt" <<'PY'
          import sys
          path = sys.argv[1]
          with open(path) as f:
              lines = f.read().splitlines()
          resource = 'resourcePacks:["AE2-Dark-Mode.v.1.18","shadowui","Modernity-GTNH-main"]'
          for i, line in enumerate(lines):
              if line.startswith('resourcePacks:'):
                  lines[i] = resource
                  break
          else:
              lines.append(resource)
          with open(path, 'w') as f:
              f.write('\n'.join(lines) + '\n')
          PY
                    fi
        '';
        # Sync is the recurring command: bootstrap first, then update to the server-published manifest.
        gtnhDailyClientSync = pkgs.writeShellScriptBin "gtnh-daily-client-sync" ''
          set -euo pipefail

          server="''${GTNH_DAILY_SERVER:-nemesis}"
          remote_manifest="/var/lib/gtnh-daily/current-manifest.json"
          remote_hash="/var/lib/gtnh-daily/current-manifest.sha256"
          instance_dir="${gtnhDailyInstanceDir}"
          state_file="$instance_dir/.gtnh-daily-updater.json"
          cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/gtnh-daily-client-sync"
          backup_dir="$HOME/.local/share/PrismLauncher/backups"
          local_manifest="$cache_dir/current-manifest.json"
          local_hash="$cache_dir/current-manifest.sha256"
          lock_file="$cache_dir/sync.lock"

          mkdir -p "$cache_dir"
          exec 9>"$lock_file"
          ${pkgs.util-linux}/bin/flock -n 9

          # Refuse mutation while Prism/Minecraft is running to avoid jar/config replacement races.
          if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f 'prismlauncher|net\.minecraft|minecraft|lwjgl3ify' >/dev/null; then
            echo "Prism or Minecraft appears to be running; refusing to update the client instance." >&2
            exit 1
          fi
          ${gtnhDailyClientBootstrap}/bin/gtnh-daily-client-bootstrap

          fetched_hash="$(${pkgs.openssh}/bin/ssh -o BatchMode=yes "$server" "cat '$remote_hash'")"
          if [ -f "$local_hash" ] && [ "$fetched_hash" = "$(cat "$local_hash")" ]; then
            echo "GTNH Daily client is already synced to $server."
            exit 0
          fi

          ${pkgs.openssh}/bin/scp -q -o BatchMode=yes "$server:$remote_manifest" "$local_manifest"
          expected_hash="$(printf '%s\n' "$fetched_hash" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
          actual_hash="$(${pkgs.coreutils}/bin/sha256sum "$local_manifest" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
          if [ "$expected_hash" != "$actual_hash" ]; then
            echo "Manifest hash mismatch: expected $expected_hash, got $actual_hash" >&2
            exit 1
          fi

          mkdir -p "$backup_dir"
          backup="$backup_dir/gtnh-daily-client-$(${pkgs.coreutils}/bin/date -u +%Y%m%d-%H%M%S).tar.zst"
          ${pkgs.gnutar}/bin/tar --use-compress-program=${pkgs.zstd}/bin/zstd -C "$HOME/.local/share/PrismLauncher/instances" -cf "$backup" "${gtnhDailyInstanceName}"

          PATH=${pkgs.git}/bin:$PATH ${gtnhDailyUpdater}/bin/gtnh-daily-updater update \
            --instance-dir "$instance_dir" \
            --manifest-file "$local_manifest"
          printf '%s\n' "$fetched_hash" > "$local_hash"

          ${pkgs.findutils}/bin/find "$backup_dir" -maxdepth 1 -type f -name 'gtnh-daily-client-*.tar.zst' -printf '%T@ %p\0' \
            | ${pkgs.coreutils}/bin/sort -z -nr \
            | ${pkgs.coreutils}/bin/tail -z -n +$(( ${toString gtnhDailyBackupRetentionCount} + 1 )) \
            | ${pkgs.gawk}/bin/awk -v RS='\0' '{ sub(/^[^ ]+ /, ""); if ($0 != "") print $0 }' \
            | ${pkgs.findutils}/bin/xargs -r -d '\n' ${pkgs.coreutils}/bin/rm -f --

          echo "Synced GTNH Daily client to $server manifest $expected_hash"
        '';
      in
      {
        # Desktop entries expose stable and Daily GTNH launches to graphical menus.
        xdg.desktopEntries = {
          gtnh = {
            name = "GregTech New Horizons";
            icon = "${config.home.homeDirectory}/.local/share/PrismLauncher/instances/GT_New_Horizons_2.8.4_Java_17-25/icon.png";
            exec = "prismlauncher --launch GT_New_Horizons_2.8.4_Java_17-25";
          };
          gtnh-daily = {
            name = gtnhDailyInstanceName;
            icon = "${gtnhDailyInstanceDir}/icon.png";
            exec = "prismlauncher --launch \"${gtnhDailyInstanceName}\" --server localhost:25566";
          };
        };
        # User packages install Prism and, on Linux, the bootstrap/sync helper commands.
        home.packages = [
          (pkgs.prismlauncher.override {
            jdks = [ pkgs.jdk25 ];
          })
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          gtnhDailyClientBootstrap
          gtnhDailyClientSync
        ];
        # User systemd timer is Linux-only; Darwin can still evaluate and install Prism.
        systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          services.gtnh-daily-client-sync = {
            Unit = {
              Description = "Sync GTNH Daily Prism client to the server manifest";
              After = [ "network-online.target" ];
            };
            Service = {
              Type = "oneshot";
              # Run sync/backup work at lower CPU and disk priority so interactive desktop use wins.
              Nice = 10;
              IOSchedulingClass = "best-effort";
              IOSchedulingPriority = 7;
              ExecStart = "${gtnhDailyClientSync}/bin/gtnh-daily-client-sync";
            };
          };
          timers.gtnh-daily-client-sync = {
            Unit.Description = "Sync GTNH Daily Prism client on schedule";
            Timer = {
              OnCalendar = "hourly";
              Persistent = true;
              RandomizedDelaySec = "15m";
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };
      };
  };
}
