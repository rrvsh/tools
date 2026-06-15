# Server architecture

For definitions of Linux, systemd, Minecraft, and Nix terms used here, see [glossary.md](./glossary.md). For line-by-line implementation reasoning, see [implementation-notes.md](./implementation-notes.md).

## Identity and paths

The Daily server is isolated from the stable GTNH server: it has a different directory, service name, Linux user, and network port. That lets the stable server and Daily server coexist without overwriting each other's files.

Stable server:

- directory: `/srv/gtnh`;
- service: `gtnh-server.service`;
- port: `25565`.

Daily server:

- user/group: `gtnh-daily:gtnh-daily`;
- home/root: `/var/lib/gtnh-daily`;
- server directory: `/var/lib/gtnh-daily/server`;
- backups: `/var/lib/gtnh-daily/backups`;
- updater cache: `/var/lib/gtnh-daily/cache`;
- updater config: `/var/lib/gtnh-daily/config`;
- published manifest: `/var/lib/gtnh-daily/current-manifest.json`;
- published manifest hash: `/var/lib/gtnh-daily/current-manifest.sha256`;
- port: `25566`.

`/var/lib/gtnh-daily` is traversable/readable enough for SSH clients to fetch the published manifest. “Traversable” means other users can pass through the directory path to read specifically world-readable files such as `current-manifest.json`. Sensitive subdirectories, such as the server files, backups, cache, config, and world data, remain private to `gtnh-daily`.

## Bootstrap service

`gtnh-daily-bootstrap.service` is a oneshot service: systemd runs it, it prepares files, and then it exits. It is ordered before `gtnh-daily-server.service` so missing server files are created before Java tries to start Minecraft.

It is idempotent, meaning it is safe to run repeatedly:

1. creates root/server/backup/cache/config directories with expected ownership/modes;
2. downloads the latest manifest if no published manifest exists;
3. downloads a non-expired GitHub Actions server artifact if launch files are missing;
4. downloads the matching manifest artifact when artifact bootstrap is used;
5. initializes updater state if `.gtnh-daily-updater.json` is missing;
6. reconciles declared extras/excludes into updater state;
7. writes or edits `eula.txt` so `eula=true`.

It does not delete worlds or overwrite an already bootstrapped server. It only creates missing bootstrap material and reconciles the small declared updater-state fields. Reconcile means “make these few fields match Nix”; manually added updater extras/excludes will be removed unless they are added to the Nix module.

## Server service

`gtnh-daily-server.service` is the actual Minecraft server process. It:

- requires the stdin FIFO socket;
- wants network-online and bootstrap;
- only starts when `java9args.txt` and `lwjgl3ify-forgePatches.jar` exist;
- runs as `gtnh-daily` in `/var/lib/gtnh-daily/server`;
- uses JDK 25 headless;
- rewrites `server-port=25566` before every start;
- starts Java with `-Xms6G -Xmx10G -XX:+UseZGC -Dfml.readTimeout=180 @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui`;
  - `-Xms6G` starts Java with 6 GiB of heap;
  - `-Xmx10G` caps Java heap at 10 GiB;
  - `-XX:+UseZGC` selects the Z garbage collector;
  - `-Dfml.readTimeout=180` gives Forge longer to wait for slow clients;
  - `@java9args.txt` loads GTNH's packaged modern-Java arguments;
  - `nogui` disables the vanilla server GUI;
- writes stdout/stderr to journald;
- uses a restrictive systemd sandbox with `/var/lib/gtnh-daily` as the writable path.

## Console stdin socket

`gtnh-daily-server.socket` creates `/run/gtnh-daily-server.stdin` as a FIFO, also called a named pipe. The service reads standard input from that pipe. This lets admin commands be sent without attaching to the Java process:

```sh
printf 'say hello\n' | sudo tee /run/gtnh-daily-server.stdin >/dev/null
printf 'stop\n' | sudo tee /run/gtnh-daily-server.stdin >/dev/null
```

`ExecStop` writes `stop`, waits up to 120 seconds, then sends SIGTERM if needed. `stop` asks Minecraft to save and shut down cleanly. SIGTERM is the operating system's polite termination signal. Exit status 143 is treated as successful because SIGTERM can be the final shutdown mechanism.

## Update service and timer

`gtnh-daily-update.service`:

1. takes `/run/gtnh-daily-update.lock` with `flock`;
2. downloads the current Daily manifest to a temp file;
3. records whether the server was active;
4. stops only `gtnh-daily-server.service`;
5. creates a pre-update tar.zst backup;
6. runs `gtnh-daily-updater update --manifest-file <temp-manifest>` as `gtnh-daily`;
7. publishes the exact manifest and SHA-256 hash;
8. restarts the server only if it was active before the update.

The timer runs daily around 05:00 with a 30 minute randomized delay. The random delay avoids every timer on the machine firing at exactly the same second. `Persistent=true` means that if the machine was off at the scheduled time, systemd starts the missed update after the machine comes back.

## Rollback

`gtnh-daily-rollback` stops the Daily server, moves the current server directory aside, extracts a selected backup (or the newest pre-update backup), fixes ownership, and starts the server again. Moving the current directory aside means it is renamed to a timestamped path instead of immediately deleted; this leaves material for manual recovery if extraction fails.

## Firewall

The NixOS module opens TCP and UDP `25566` for Minecraft. GTNH-Web-Map listens on TCP `8123`; expose that separately only if you intentionally want the browser map reachable, and decide separately whether it should be local-only, LAN-only, VPN-only, or reverse-proxied.

## World data boundary

`World/` is mutable and intentionally not recreated by Nix. It contains player builds, inventories, dimensions, chunks, and mod world data. A wiped disk without a world backup yields a fresh/no world according to the bootstrapped server files. A restored world can be placed under `/var/lib/gtnh-daily/server/World` without conflicting with declarative bootstrap, then owned with `sudo chown -R gtnh-daily:gtnh-daily /var/lib/gtnh-daily/server/World`.
