# GT New Horizons Daily administration guide

This guide documents the isolated GT New Horizons Daily setup managed by this repo. It covers day-to-day administration, bootstrap/recovery commands, client/server synchronization, and implementation details from the initial setup session.

## Overview

The Daily environment is intentionally separate from the stable GTNH server:

| Concern | Stable | Daily |
| --- | --- | --- |
| Server directory | `/srv/gtnh` | `/var/lib/gtnh-daily/server` |
| Main service | `gtnh-server.service` | `gtnh-daily-server.service` |
| Update service | existing stable flow | `gtnh-daily-update.service` |
| Backups | existing stable flow | `/var/lib/gtnh-daily/backups` |
| Minecraft port | `25565` | `25566` |
| User | existing stable user | `gtnh-daily` |

Daily builds come from the GTNH Dev Builds pipeline in `GTNewHorizons/DreamAssemblerXXL`, workflow `daily-modpack-build.yml`. The server update service publishes the exact manifest it applied, and the Prism client sync command pulls that manifest over SSH so the client updates to the same Daily build as the server.

## Important paths and units

Server-side paths:

```text
/var/lib/gtnh-daily
/var/lib/gtnh-daily/server
/var/lib/gtnh-daily/backups
/var/lib/gtnh-daily/cache
/var/lib/gtnh-daily/config
/var/lib/gtnh-daily/current-manifest.json
/var/lib/gtnh-daily/current-manifest.sha256
```

Client-side paths:

```text
~/.local/share/PrismLauncher/instances/GT New Horizons (Daily)
~/.local/share/PrismLauncher/instances/GT New Horizons (Daily)/.gtnh-daily-updater.json
~/.local/share/PrismLauncher/backups
~/.cache/gtnh-daily-client-sync/current-manifest.json
~/.cache/gtnh-daily-client-sync/current-manifest.sha256
```

System units:

```text
gtnh-daily-server.service
gtnh-daily-server.socket
gtnh-daily-update.service
gtnh-daily-update.timer
```

User units:

```text
gtnh-daily-client-sync.service
gtnh-daily-client-sync.timer
```

Installed commands:

```text
gtnh-daily-updater
gtnh-daily-rollback
gtnh-daily-client-sync
```

## Daily server operations

Check the stable and Daily servers:

```sh
systemctl is-active gtnh-server.service gtnh-daily-server.service
```

Start the Daily server:

```sh
sudo systemctl start gtnh-daily-server.service
```

Stop the Daily server:

```sh
sudo systemctl stop gtnh-daily-server.service
```

Follow server logs:

```sh
sudo journalctl -u gtnh-daily-server.service -f
```

Verify the Daily server port:

```sh
sudo grep -n '^server-port=' /var/lib/gtnh-daily/server/server.properties
```

The service rewrites `server-port=25566` in `server.properties` before every start to avoid conflict with the stable server.

Send a Minecraft console command through the service FIFO:

```sh
printf 'say hello from systemd\n' | sudo tee /run/gtnh-daily-server.stdin >/dev/null
```

Whitelist and op a player:

```sh
printf 'whitelist add wagoqi\n' | sudo tee /run/gtnh-daily-server.stdin >/dev/null
printf 'op wagoqi\n' | sudo tee /run/gtnh-daily-server.stdin >/dev/null
```

Verify whitelist/op state:

```sh
sudo grep -R 'wagoqi' \
  /var/lib/gtnh-daily/server/whitelist.json \
  /var/lib/gtnh-daily/server/ops.json
```

## Server updates and backups

Run a Daily update immediately:

```sh
sudo systemctl start gtnh-daily-update.service
```

Check update logs:

```sh
sudo journalctl -u gtnh-daily-update.service -n 120 --no-pager
```

Check the timer:

```sh
systemctl list-timers --all 'gtnh-daily-update.timer' --no-pager
```

The timer runs daily around 05:00 with a randomized delay:

```text
OnCalendar=*-*-* 05:00:00
RandomizedDelaySec=30m
Persistent=true
```

A server update does the following:

1. Acquires `/run/gtnh-daily-update.lock` with `flock` so updates cannot overlap.
2. Downloads the current Daily manifest from `https://raw.githubusercontent.com/GTNewHorizons/DreamAssemblerXXL/master/releases/manifests/daily.json` into a temporary file.
3. Records whether `gtnh-daily-server.service` was active before the update.
4. Stops only `gtnh-daily-server.service`; the stable `gtnh-server.service` is untouched.
5. Creates a pre-update backup under `/var/lib/gtnh-daily/backups`.
6. Runs `gtnh-daily-updater update --manifest-file <downloaded-manifest> --instance-dir /var/lib/gtnh-daily/server` as user `gtnh-daily`.
7. Publishes the exact applied manifest and SHA-256 hash:
   - `/var/lib/gtnh-daily/current-manifest.json`
   - `/var/lib/gtnh-daily/current-manifest.sha256`
8. Restarts the Daily server only if it was active before the update.

List backups:

```sh
sudo ls -lh /var/lib/gtnh-daily/backups
```

The latest pre-update backup is also symlinked as:

```text
/var/lib/gtnh-daily/backups/latest.tar.zst
```

## Server rollback

Rollback to the latest pre-update backup:

```sh
sudo gtnh-daily-rollback
```

Rollback to a specific backup:

```sh
sudo gtnh-daily-rollback /var/lib/gtnh-daily/backups/pre-update-YYYYmmdd-HHMMSS.tar.zst
```

Rollback behavior:

1. Stops only `gtnh-daily-server.service`.
2. Moves the current server directory to `/var/lib/gtnh-daily/server.rollback-<timestamp>`.
3. Extracts the selected backup into `/var/lib/gtnh-daily/server`.
4. Fixes ownership to `gtnh-daily:gtnh-daily`.
5. Starts `gtnh-daily-server.service`.

## Prism client operations

The Daily Prism instance is named exactly:

```text
GT New Horizons (Daily)
```

The desktop entry runs:

```sh
prismlauncher --launch "GT New Horizons (Daily)"
```

Run a manual client sync:

```sh
gtnh-daily-client-sync
```

Use a different SSH server host for one run:

```sh
GTNH_DAILY_SERVER=nemesis gtnh-daily-client-sync
```

Check the user timer:

```sh
systemctl --user list-timers --all 'gtnh-daily-client-sync.timer' --no-pager
```

Start the sync user service manually:

```sh
systemctl --user start gtnh-daily-client-sync.service
```

Read sync logs:

```sh
journalctl --user -u gtnh-daily-client-sync.service -n 120 --no-pager
```

The client sync command:

1. Uses SSH to read the server's `/var/lib/gtnh-daily/current-manifest.sha256` from `nemesis` by default.
2. Exits if the local applied hash in `~/.cache/gtnh-daily-client-sync/current-manifest.sha256` matches the server hash.
3. Refuses to run if Prism or Minecraft appears to be running.
4. Copies `/var/lib/gtnh-daily/current-manifest.json` from the server with `scp`.
5. Verifies the copied manifest against the server-published hash.
6. Creates a full client instance backup under `~/.local/share/PrismLauncher/backups`.
7. Runs:

   ```sh
   gtnh-daily-updater update \
     --instance-dir "$HOME/.local/share/PrismLauncher/instances/GT New Horizons (Daily)" \
     --manifest-file "$HOME/.cache/gtnh-daily-client-sync/current-manifest.json"
   ```

8. Writes the applied server hash to `~/.cache/gtnh-daily-client-sync/current-manifest.sha256`.

The client sync timer is hourly with a 15 minute randomized delay and `Persistent=true`.

## Initial client updater state

A Prism instance must be initialized once before `gtnh-daily-client-sync` can update it. If state is missing, the sync command prints the init command and exits.

Initialize the Daily Prism instance against the server's current config version:

```sh
config=$(ssh nemesis "python3 - <<'PY'
import json
with open('/var/lib/gtnh-daily/current-manifest.json') as f:
    print(json.load(f)['config'])
PY
")
gtnh-daily-updater init \
  --instance-dir "$HOME/.local/share/PrismLauncher/instances/GT New Horizons (Daily)" \
  --side client \
  --config "$config"
```

If Python is unavailable on the server, copy the manifest locally and inspect it with any JSON tool:

```sh
scp nemesis:/var/lib/gtnh-daily/current-manifest.json /tmp/gtnh-daily-current-manifest.json
jq -r .config /tmp/gtnh-daily-current-manifest.json
```

## Bootstrap from GitHub Actions artifacts

Normal updates do not need GitHub Actions artifact downloads; they use `gtnh-daily-updater` and the published Daily manifest. Artifact downloads are only needed for first bootstrap or full manual re-seeding.

List recent successful Daily workflow runs:

```sh
gh run list \
  -R GTNewHorizons/DreamAssemblerXXL \
  -w daily-modpack-build.yml \
  --limit 10
```

Inspect a run:

```sh
gh run view <run-id> -R GTNewHorizons/DreamAssemblerXXL
gh api repos/GTNewHorizons/DreamAssemblerXXL/actions/runs/<run-id>/artifacts \
  --jq '.artifacts[] | [.name,.size_in_bytes,.expired] | @tsv'
```

Expected artifact names include:

```text
GTNH-daily-YYYY-MM-DD+NNN-mmcprism-java17-25.zip
GTNH-daily-YYYY-MM-DD+NNN-server-java17-25.zip
gtnh-daily-YYYY-MM-DD+NNN-manifest.json
daily-build-bundle
```

Download a server artifact and manifest:

```sh
gh run download <run-id> \
  -R GTNewHorizons/DreamAssemblerXXL \
  -n GTNH-daily-YYYY-MM-DD+NNN-server-java17-25.zip \
  -n gtnh-daily-YYYY-MM-DD+NNN-manifest.json \
  --dir /tmp/gtnh-daily-bootstrap
```

`gh run download` extracts each artifact into a directory named after the artifact. Seed the server with:

```sh
sudo cp -a /tmp/gtnh-daily-bootstrap/GTNH-daily-YYYY-MM-DD+NNN-server-java17-25.zip/. \
  /var/lib/gtnh-daily/server/
sudo chown -R gtnh-daily:gtnh-daily /var/lib/gtnh-daily
```

Extract the config version from the downloaded manifest. It looks like:

```json
{ "config": "2.9.0-nightly-2026-06-12" }
```

Initialize server updater state:

```sh
sudo -u gtnh-daily env HOME=/var/lib/gtnh-daily \
  XDG_CACHE_HOME=/var/lib/gtnh-daily/cache \
  XDG_CONFIG_HOME=/var/lib/gtnh-daily/config \
  PATH=/run/current-system/sw/bin \
  gtnh-daily-updater init \
  --instance-dir /var/lib/gtnh-daily/server \
  --side server \
  --config <manifest-config-field>
```

Accept the Minecraft EULA before starting the server:

```sh
sudo sed -i 's/^eula=false/eula=true/' /var/lib/gtnh-daily/server/eula.txt
```

### Manual daily extras: GTNH-Web-Map, ServerUtilities chunkloading, MineMenu

These extras are intentionally manual because they are server/client instance state, not Nix-managed package state.

Install GTNH-Web-Map and MineMenu on the server:

```sh
sudo install -d -o gtnh-daily -g gtnh-daily -m 0750 /var/lib/gtnh-daily/server/mods
sudo find /var/lib/gtnh-daily/server/mods -maxdepth 1 -type f \
  \( -name 'gtnh-web-map-*.jar' -o -name 'DynmapForge-*.jar' -o -name 'MineMenu-*.jar' \) -delete
sudo install -o gtnh-daily -g gtnh-daily -m 0640 /path/to/gtnh-web-map-0.4-beta-1.jar \
  /var/lib/gtnh-daily/server/mods/gtnh-web-map-0.4-beta-1.jar
sudo install -o gtnh-daily -g gtnh-daily -m 0640 /path/to/MineMenu-1.7.10-1.2.0.B44-universal.jar \
  /var/lib/gtnh-daily/server/mods/MineMenu-1.7.10-1.2.0.B44-universal.jar
```

Enable ServerUtilities chunk claiming/loading and ranks in `/var/lib/gtnh-daily/server/serverutilities/serverutilities.cfg`:

```cfg
ranks {
    B:enabled=true
}

world {
    B:chunk_claiming=true
    B:chunk_loading=true
}
```

Install MineMenu on each Prism client instance too:

```sh
mods_dir="$HOME/.local/share/PrismLauncher/instances/GT New Horizons (Daily)/.minecraft/mods"
mkdir -p "$mods_dir"
find "$mods_dir" -maxdepth 1 -type f -name 'MineMenu-*.jar' -delete
install -m 0644 /path/to/MineMenu-1.7.10-1.2.0.B44-universal.jar \
  "$mods_dir/MineMenu-1.7.10-1.2.0.B44-universal.jar"
```

Restart the server after changing server-side mods/config. GTNH-Web-Map listens on TCP `8123` by default, so expose that port where appropriate.

### 2026-06-13 world migration from stable, player data stripped

The Daily server was migrated to a copy of the stable `/srv/gtnh` world while stripping player state. `/srv/gtnh` itself was only stopped/read/backed up/restarted; its files were not otherwise modified.

Backups created before the migration:

```text
/var/lib/gtnh-daily/backups/source-srv-gtnh-20260613-105333.tar.zst
/var/lib/gtnh-daily/backups/pre-stripped-world-20260613-105333.tar.zst
```

Procedure performed:

1. Stopped `gtnh-server.service` and `gtnh-daily-server.service` for a consistent copy.
2. Archived `/srv/gtnh` into the Daily backup directory.
3. Archived the previous Daily server directory.
4. Copied `/srv/gtnh/world` into the Daily server.
5. Corrected the copied directory to the active Daily level name, `World`, because Daily has `level-name=World` in `server.properties`.
6. Removed old Daily in-instance `server/backups`; the canonical migration backups are in `/var/lib/gtnh-daily/backups`.
7. Stripped player data from the copied world:
   - `World/playerdata`
   - `World/stats`
   - BetterQuesting `QuestProgress`, `NameCache`, `LifeDatabase`, `QuestingParties`
   - ServerUtilities world players/teams/claims
   - backpack player data
   - NEI player data
   - Baubles and Thaumcraft username files
   - OpenBlocks grave/death inventory backups
   - Forestry player trackers
   - POBox player data
   - KubaTech player data
   - mobsinfo player data
   - LootBags player-ish data
   - ThaumicExploration player warp queue
   - nicknames
   - LogisticPipes player/name info
   - Daily sidecar `journeymap` and `visualprospecting`
8. Reset root identity files: `usercache.json`, `whitelist.json`, `ops.json`, `banned-players.json`, and removed `usernamecache.json`.
9. Restarted both servers.
10. Accepted the expected FML/ChunkAPI migration prompts with `/fml confirm`; this was expected because the stable source world was GTNH 2.8.4 and Daily has newer mod IDs/managers.
11. Verified Daily reached `Done`, listened on `25566`, and GTNH-Web-Map served on `8123`.
12. Re-added `wagoqi` to the Daily whitelist and ops:

```sh
printf 'whitelist add wagoqi\nop wagoqi\n' | sudo tee /run/gtnh-daily-server.stdin >/dev/null
```

Post-checks:

- `gtnh-server.service`: active
- `gtnh-daily-server.service`: active
- Daily map: `http://nemesis:8123/`
- No old `wagoqi`, `22c6c7d9-3c10-41a0-9e9d-759f2aeec75b`, or `e43c1aea-e5b8-3c4f-95b0-ef6163be3402` references remained in active Daily server data after excluding logs/mods/libraries/dynmap/backups.
- New `wagoqi` whitelist/op entries were regenerated with UUID `22c6c7d9-3c10-41a0-9e9d-759f2aeec75b`.

## Implementation notes

### Nix package

The repo packages `Caedis/gtnh-daily-updater` with `pkgs.buildGoModule` from a flake input:

```nix
gtnh-daily-updater = {
  url = "github:Caedis/gtnh-daily-updater";
  flake = false;
};
```

The package uses the upstream source as `src`, sets a fixed Go `vendorHash`, and includes `git` in `nativeCheckInputs` because upstream tests invoke `git`.

A local Nix patch adds `--manifest-file` support to the updater. The patch is applied with the package's `patches` attribute, so no fork is needed:

```nix
patches = [ ./patches/gtnh-daily-updater-manifest-file.patch ];
```

The patch is intentionally small: it adds a CLI flag, expands `~` in that flag, adds `ManifestFile` to updater options, loads that JSON manifest when present, and otherwise preserves upstream behavior.

### Why pinned manifests are needed

Upstream `gtnh-daily-updater update` normally fetches the latest manifest at runtime. That is fine for a single machine, but it is not sufficient for exact client/server sync. If the server updates at 05:00 and the client syncs after a newer Daily appears, an unpinned client update could jump ahead of the server.

The patched `--manifest-file` mode lets the server publish the exact manifest it used and lets every client update against that same manifest. The assets database is still fetched normally by the updater to resolve downloads, but mod/config selection is pinned to the server-applied Daily manifest.

### Server module

`nix/modules/gtnh-daily-server.nix` defines one isolated NixOS module. It creates the `gtnh-daily` system user/group, tmpfiles directories, firewall openings for TCP/UDP `25566`, a socket-backed stdin FIFO, the server service, the update service/timer, and the rollback command.

The server uses `jdk25_headless` and starts with:

```text
-Xms6G
-Xmx10G
-XX:+UseZGC
-Dfml.readTimeout=180
@java9args.txt
-jar lwjgl3ify-forgePatches.jar
nogui
```

`gtnh-daily-server.socket` creates `/run/gtnh-daily-server.stdin`, which systemd connects to the Java process as standard input. This allows admin commands such as `stop`, `whitelist add`, and `op` to be sent without attaching to a terminal.

`ExecStop` sends `stop` through the FIFO, waits up to 120 seconds, then sends `SIGTERM` if the process is still alive. `SuccessExitStatus = "0 143"` treats a final SIGTERM exit as successful.

The update service intentionally only stops/restarts the Daily server. It records whether the Daily server was active before updating and restarts it only in that case, so a manually stopped Daily server stays stopped across scheduled updates.

### Client module

`nix/modules/prismlauncher.nix` manages Prism Launcher with JDK 25, the stable GTNH desktop entry, the Daily desktop entry, and the Linux-only client sync helper/timer. The client sync package and user systemd units are only enabled when Home Manager is evaluated for Linux, so the shared Prism module still evaluates on Darwin.

`gtnh-daily-client-sync` defaults to `nemesis` as the SSH source host. Override per invocation with:

```sh
GTNH_DAILY_SERVER=<host> gtnh-daily-client-sync
```

The command is installed only on Linux Home Manager systems because it depends on Linux-oriented tools and user systemd integration.

### Filesystem permissions

`/var/lib/gtnh-daily` is mode `0755` so SSH users can traverse it and read the published manifest files. This is enforced both by the tmpfiles rule and by `users.users.gtnh-daily.homeMode = "0755"`, so rebuild/user activation does not reset the home directory back to a private mode. Sensitive subdirectories remain private:

```text
/var/lib/gtnh-daily/server   0750 gtnh-daily:gtnh-daily
/var/lib/gtnh-daily/backups  0750 gtnh-daily:gtnh-daily
/var/lib/gtnh-daily/cache    0750 gtnh-daily:gtnh-daily
/var/lib/gtnh-daily/config   0750 gtnh-daily:gtnh-daily
```

The published files are mode `0644`:

```text
/var/lib/gtnh-daily/current-manifest.json
/var/lib/gtnh-daily/current-manifest.sha256
```

## Session record

The setup was built in stages:

1. Added `Caedis/gtnh-daily-updater` as a `flake = false` input and packaged it with `pkgs.buildGoModule`.
2. Added the package to Home Manager development packages.
3. Verified no existing nixpkgs package for `gtnh-daily-updater` was available.
4. Resolved and documented the Go `vendorHash`. Upstream does not commit a `vendor/` directory, so `vendorHash = null` is not appropriate.
5. Added `nativeCheckInputs = [ pkgs.git ]` because upstream tests call `git`.
6. Inspected the GTNH Dev Builds documentation and confirmed Daily builds come from `GTNewHorizons/DreamAssemblerXXL` workflow `daily-modpack-build.yml`, not from `GT-New-Horizons-Modpack` releases.
7. Downloaded authenticated GitHub Actions artifacts with `gh run download`.
8. Bootstrapped `/var/lib/gtnh-daily/server` from `GTNH-daily-2026-06-12+569-server-java17-25.zip`.
9. Initialized server updater state with config version `2.9.0-nightly-2026-06-12`.
10. Accepted the Minecraft EULA in `/var/lib/gtnh-daily/server/eula.txt`.
11. Added `gtnh-daily-server.service` and verified it can run alongside the stable server.
12. Added scheduled pre-update backups and rollback via `gtnh-daily-rollback`.
13. Verified `gtnh-server.service` stayed active while the Daily server and updater were tested.
14. Added a Daily Prism desktop entry for the already-created Prism instance.
15. Added a local patch to `gtnh-daily-updater` for `--manifest-file` because exact client/server sync requires pinning the manifest.
16. Changed the server update service to publish the exact applied manifest and hash.
17. Initialized the local Daily Prism instance updater state.
18. Added `gtnh-daily-client-sync` and an hourly user timer.
19. Tested client sync over SSH against `nemesis`; it verified the hash, created a client backup, and reported the client already up to date.
20. Reviewed the full diff since `prime`, made the client sync package Linux-only for shared Home Manager evaluation, and set `gtnh-daily.homeMode = "0755"` so the published manifest remains reachable over SSH after rebuilds.

Validation performed during the session included:

```sh
nix build .#gtnh-daily-updater --no-link
nix develop -c just check-nix
nix build .#nixosConfigurations.nemesis.config.system.build.toplevel --no-link
nix develop -c just rb
sudo systemctl start gtnh-daily-update.service
gtnh-daily-client-sync
systemctl is-active gtnh-server.service gtnh-daily-server.service
systemctl list-timers --all 'gtnh-daily-update.timer' --no-pager
systemctl --user list-timers --all 'gtnh-daily-client-sync.timer' --no-pager
```

At the end of setup, both stable and Daily servers were active, the Daily server was on port `25566`, the server update timer was enabled, and the client sync timer was enabled.
