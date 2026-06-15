# Implementation notes for reading the Nix code

This page explains why `nix/modules/gtnh-daily-server.nix` and `nix/modules/prismlauncher.nix` look the way they do. It is a companion to the inline comments in those files.

## Why the code mixes Nix, shell, and Python

- **Nix** declares packages, services, timers, files, and generated scripts.
- **Shell** is used for service actions: create directories, download files, stop/start services, call the updater, and run `systemctl`.
- **Python** is used only where structured JSON/file manipulation is clearer and safer than shell string editing.

The generated shell scripts are still reproducible because Nix writes their exact text into the Nix store.

## Shared code-reading assumptions

- `pkgs` is the package set. Paths such as `${pkgs.curl}/bin/curl` point at an exact Nix-built program, not whatever happens to be on `PATH`.
- `${...}` inside a Nix string inserts a Nix value into the generated file/script.
- Shell snippets use `set -euo pipefail` so unexpected errors abort instead of continuing with a half-written instance.
- Most scripts create directories every run. That is deliberate: directory creation with fixed ownership/permissions is idempotent.
- State files are edited narrowly. The code reconciles only the fields it owns, such as updater extras/excludes, instead of rewriting unrelated updater state.

## `nix/modules/gtnh-daily-server.nix`

### Overall shape

The file defines one NixOS module named `gtnh-daily-server`. A NixOS module is a reusable piece of system configuration. This one declares:

- the `gtnh-daily` system user and group;
- persistent directories under `/var/lib/gtnh-daily`;
- the bootstrap, server, update, rollback, socket, and timer units;
- the firewall opening for Minecraft port `25566`;
- helper scripts installed into the system.

The top-level `{ inputs, ... }:` receives flake inputs, including this repo's packaged `gtnh-daily-updater`.

### Important paths and variables

- `user`, `group`, and `unit` are separate so service names, ownership, and paths stay consistent without repeating strings.
- `rootDir = /var/lib/gtnh-daily` follows Linux convention: long-lived service data belongs under `/var/lib`.
- `serverDir = /var/lib/gtnh-daily/server` is the actual Minecraft server directory.
- `stdin = /run/gtnh-daily-server.stdin` is a temporary FIFO path used to send console commands.
- `lockFile = /run/gtnh-daily-update.lock` prevents overlapping server updates.
- `manifestUrl` is GTNH's moving latest Daily manifest URL. The server downloads it into a local temp file, then publishes the exact file it used.
- `port = 25566` avoids conflict with the stable server on the normal Minecraft port `25565`.
- `pkgs.jdk25_headless` is Java 25 without desktop pieces; it is enough for the server.
- The `tar` command includes zstd compression and preserves extended attributes/ACLs where possible.
- `updaterEnv` sets `HOME`, `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, and `PATH` so the updater stores cache/config under `/var/lib/gtnh-daily` and can find required tools such as git.

### Declared extras/excludes

Nix stores the desired server updater policy as JSON:

- exclude `JourneyMap Server`;
- add/override `GTNH-Web-Map` from GitHub;
- add `MineMenu` from one exact Modrinth version.

`builtins.toJSON` renders the Nix data as JSON. `pkgs.writeText` writes that JSON into an immutable Nix store file that the script can read.

### `reconcileState`

This generated helper updates `.gtnh-daily-updater.json` after init/bootstrap.

- Python is used because JSON editing in shell is fragile.
- Invalid JSON fails the script, intentionally: continuing would risk corrupting updater state.
- The code replaces `exclude_mods` and `extra_mods` exactly because those fields are owned by Nix policy. Manual additions to those fields will be removed on the next bootstrap/update; add wanted entries to Nix instead.
- Ownership is reset to `gtnh-daily:gtnh-daily` because services run as that user.

### Bootstrap script

Bootstrap creates the minimum required server files when a server does not already exist.

- `install -d` creates directories with owner/group/mode in one command.
- The script fetches the latest manifest only if no published manifest exists yet.
- `mktemp` creates safe temporary files/directories.
- The manifest hash file stores the SHA-256 plus filename, the normal `sha256sum` format. Consumers compare the first field for the actual hash.
- GitHub Actions artifacts do not have one stable URL, so the script asks the GitHub API for recent successful workflow runs and their artifact URLs.
- `GITHUB_TOKEN`, when present, is sent as an API authorization header. The `auth=()` array is a shell array; the unusual quoting is how Nix emits shell array syntax without treating it as Nix interpolation.
- Searching the 20 most recent successful runs is a practical balance: enough history to skip expired/incomplete runs without spending too long.
- Embedded Python parses GitHub JSON responses safely and prints shell assignments for the selected artifact URLs.
- `eval` is used only on output produced by our embedded Python from GitHub JSON values that are shell-quoted by `shlex.quote`.
- The script requires both a server artifact and its manifest artifact for artifact bootstrap, so the initial files and manifest config version come from the same Daily run.
- The manifest artifact is zipped by GitHub even though it contains a JSON file, so the script unzips it and requires exactly one JSON file.
- `cp -a "$tmp/server/."` copies the artifact contents while preserving attributes.
- The artifact is extracted only when launch files are missing. If `java9args.txt` exists but another required launch file is missing, systemd's `ConditionPathExists` prevents server start; repair by deleting/recreating the incomplete instance or inspecting manually.
- Updater init runs only after files exist because it scans the actual jars/configs.
- `runuser -u gtnh-daily` runs the updater as the service user so generated files have normal ownership.
- `eula.txt` is written/edited automatically because the server cannot start without it. The operator is responsible for agreeing to Mojang's terms.

### Stop script

The stop helper receives the Java process ID from systemd as `$1`.

1. It writes `stop` to the FIFO so Minecraft can save and shut down cleanly.
2. It waits up to 120 seconds.
3. If Java is still running, it sends SIGTERM.

If writing to the FIFO fails, the script still eventually uses SIGTERM. If Java ignores SIGTERM, systemd's normal service stop timeout/kill behavior applies.

### Backup script

The backup covers `/var/lib/gtnh-daily/server`, including the world if present. That is useful for pre-update rollback, but it is not a replacement for independent long-term world backups.

- UTC timestamps sort consistently regardless of local timezone.
- `latest.tar.zst` is a symlink to the newest backup for easy rollback.
- Ownership is set on the archive; symlink ownership is usually not meaningful for access control.

### Update script

- File descriptor `9` is a conventional spare descriptor used by `flock`.
- If another update already holds the lock, the service fails instead of overlapping.
- The manifest is downloaded before stopping the server to reduce downtime.
- The server stop command uses `|| true` because it is okay if the server was already stopped or exits oddly during shutdown; update status should reflect updater/backup/publish failures, not a harmless stop race.
- `cleanup` removes temporary files. `finish` runs at exit and restarts the server only if it had been active before update.
- The restart trap is installed once; it should not run twice.
- Extras/excludes are reconciled before update so the updater applies declared policy.
- The manifest is published only after updater success. If publishing the manifest/hash fails, the service fails and the client will not record a new applied hash.
- A backup is created before every manual/timer update, even if the updater later finds little to change.

### Rollback

`gtnh-daily-rollback` requires root because it moves service-owned files and controls system services.

- Without an argument it uses `latest.tar.zst`.
- It stops the Daily server, moves the current server directory aside with a timestamp, extracts the backup, fixes ownership, and starts the server.
- If extraction fails after the move, the moved-aside directory remains for manual recovery.
- Rollback restores whatever was in the backup's `server/` tree. It does not restore `/var/lib/gtnh-daily/current-manifest.json`, which lives outside `server/`; run client sync/update carefully after rollback if client/server versions matter.

### tmpfiles, socket, services, timer, firewall

- tmpfiles creates directories and fixes basic ownership/modes. It does not overwrite normal file contents.
- `ListenFIFO` creates the named pipe used for server console input.
- `SocketMode=0660` lets owner/group write to the FIFO; others cannot.
- `RemoveOnStop` removes the FIFO when the socket stops; `FlushPending` discards stale pending input.
- Bootstrap is wanted by `multi-user.target` so it runs on boot/activation.
- The server service requires the socket and wants bootstrap/network so command input exists and missing files are created first.
- `path = [...]` makes listed commands available to service scripts without hard-coding every executable.
- `preStart` rewrites `server.properties` to keep the port correct. If the file is absent, it creates a minimal `server-port=25566` line.
- The timer's `Persistent=true` means if the machine was off at 05:00, systemd runs the missed timer after boot.
- Web-map port `8123` is not opened here because exposing a browser map may need separate access-control/reverse-proxy/firewall decisions.

## `nix/modules/prismlauncher.nix`

### Overall shape

This file groups one concern: Prism Launcher and the GTNH Daily client. It exports:

- Darwin and NixOS wrapper modules that attach a shared Home Manager module;
- the Home Manager module that installs Prism, desktop entries, client scripts, and the user timer.

Daily sync is Linux-only because it uses systemd user timers/services. Darwin users can still use Prism and could run equivalent commands manually, but this repo does not declare macOS launchd automation for Daily.

### Instance paths

- `gtnhDailyInstanceName` must match Prism's instance name exactly because Prism launch commands and paths use that string.
- If the user renames the instance, the declared desktop entry and sync scripts will manage/create the old name again.
- `config.home.homeDirectory` is Home Manager's current user's home directory.
- The code assumes Prism's normal Linux path under `~/.local/share/PrismLauncher`. If Prism is configured to store instances elsewhere, this module would need an option/change.

### Client assets JSON

The module declares resource/shader packs as JSON so the Python bootstrap code can iterate over a simple data file.

- `stripRoot = true` means “after unzipping, remove the single top-level directory and use its contents as the resource pack directory.” Modernity's GitHub archive contains a commit-named top directory, so it needs this.
- SHA-256 values were calculated from the intended downloads and rechecked by downloading each URL.
- When updating a pack version, update the URL, filename/extract directory if needed, and SHA-256 together.
- If a URL disappears, bootstrap will fail clearly instead of silently using an unknown file.
- The Complementary shader sidecar is generated in code because it is tiny text, not a downloaded binary artifact.

### Client updater state JSON

The client declares only extras because no client manifest mod is excluded outright. JourneyMap is declared as an extra with the manifest name `JourneyMap`, so it overrides the manifest's FairPlay jar with the Unlimited jar. MineMenu is pinned to exact Modrinth version `HNivj4HD` for repeatability.

Manual client extras in `.gtnh-daily-updater.json` will be overwritten by Nix reconciliation. Add desired extras to the Nix module instead.

### `gtnh-daily-client-bootstrap`

This script exists as an installed user command so the same logic can be run manually, by sync, or by future automation.

- It defaults `GTNH_DAILY_SERVER` to `nemesis`, this repo's Daily server host.
- SSH `BatchMode=yes` means “do not prompt for passwords”; if SSH keys/config are missing, fail instead of hanging in a timer.
- The process check uses `pgrep` for Prism/Minecraft/LWJGL3ify names. It may false-positive on oddly named processes, but that is safer than changing files while the game is running.
- The server hash is fetched before and after copying the manifest so the script can verify the manifest against the server's published hash.
- Only the first field of the `sha256sum` file is compared because the rest is just the filename.
- Artifact bootstrap uses a recent Prism artifact only when `.minecraft` is missing. It then initializes/updates against the server-published manifest, so a newer bootstrap artifact does not define the final target version; the server manifest does.
- If `.minecraft` exists but is incomplete, bootstrap assumes it is intentional and does not overwrite it. Repair by moving the broken instance aside or deleting it after backing up anything important.
- The artifact is copied into the Prism instance root because Prism/MultiMC artifacts contain both launcher metadata and the `.minecraft` game directory.
- Updater init runs only when `.gtnh-daily-updater.json` is missing. If the state file exists but has the wrong side or bad contents, the updater/sync should fail; inspect or remove the broken state file intentionally.
- `git` is put in `PATH` because updater config merging uses git.
- Resource/shader directories are chmodded to user-writable/readable values to fix old copies that may have arrived read-only from zips.
- `.gtnh-configs/resourcepacks` is also chmodded because the updater may snapshot resource pack config state there.
- Each unpacked resource pack has a `.sha256` marker. If the source zip hash changes, bootstrap deletes and re-extracts the directory.
- If extraction fails partway, the script exits. The next run will retry because the marker will be missing or wrong.
- The Complementary sidecar is written every run so the desired text setting is restored.
- `options.txt` is edited only when it exists. Artifact bootstrap normally creates it. If it is missing, Minecraft/Prism can create defaults later, and a later bootstrap/sync can write the resource-pack line.

### `gtnh-daily-client-sync`

Sync is the normal command because it performs both “make sure the instance exists” and “update to the server manifest.”

- It takes a user lock to avoid overlapping manual/timer syncs.
- It runs bootstrap first so a wiped client can recover with one command.
- It fetches the hash again after bootstrap because bootstrap may have taken time and the server could have updated meanwhile.
- The local applied hash is the server manifest hash from the last successful updater run. It is written only after updater success.
- Comparing full hash-file text can be stricter than comparing only the first field; if whitespace/filename format ever changes, sync may do an unnecessary update rather than skipping one.
- A full instance backup is created before every update. It is a directory copy under Prism's backups directory, not zstd-compressed. Old backups are not pruned by this script.
- If backup creation fails, update does not run.
- If updater succeeds but writing the local hash fails, the next sync may repeat the update; that is safer than claiming success without a marker.

### Desktop entries and packages

- `xdg.desktopEntries` creates graphical launcher entries.
- The stable icon path is hard-coded to the known stable instance path; if the icon disappears, the launcher entry may show a generic icon but still launch.
- Daily launches `localhost:25566` instead of `nemesis:25566` so the same entry works for local servers and SSH tunnels.
- `pkgs.prismlauncher.override { jdks = [ pkgs.jdk25 ]; }` installs Prism with Java 25 available in its Java list.
- Bootstrap/sync are installed only on Linux because they rely on Linux paths and user systemd automation.

### User systemd timer

- A user systemd service runs as the normal desktop user, not root. That is required because Prism instances live under the user's home directory.
- `After = [ "network-online.target" ]` is a best-effort ordering hint in user systemd; the script still fails cleanly if SSH/network is unavailable.
- The timer is enabled by `Install.WantedBy = [ "timers.target" ]`.
- If the timer fires while Prism/Minecraft is open, sync refuses to mutate files and exits.
- Logs are visible with `journalctl --user -u gtnh-daily-client-sync.service`.
