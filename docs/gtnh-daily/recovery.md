# Recovery and rebuild guide

For definitions of commands/services mentioned here, see [glossary.md](./glossary.md). This page is the practical checklist.

## Fresh machine expectation

A “fresh machine” can mean a new disk, a reinstalled OS, or a NixOS rebuild where `/var/lib/gtnh-daily` and the Prism instance are missing. After a disk wipe and rebuild, the declarative setup should provide:

- `gtnh-daily-updater` package with local `--manifest-file` patch;
- `gtnh-daily` system user/group and directories;
- `gtnh-daily-bootstrap.service`;
- `gtnh-daily-server.service` and FIFO socket;
- `gtnh-daily-update.service` and timer;
- `gtnh-daily-rollback` command;
- Prism Launcher with JDK 25;
- `gtnh-daily-client-bootstrap` and `gtnh-daily-client-sync`;
- user sync service/timer;
- declared resource/shader pack downloads and shader sidecar text.

It should not provide the old `World/` unless you separately restore a world backup.

## Server from scratch

On first boot/rebuild activation, `gtnh-daily-bootstrap.service` is wanted by `multi-user.target` and ordered before the server. It creates the server if needed. If GitHub artifact downloads require authentication, make `GITHUB_TOKEN` available to the service environment before running bootstrap.

If GitHub artifact downloads need authentication, create a token with permission to read public GitHub Actions artifacts and provide it when manually running bootstrap:

```sh
sudo systemctl set-environment GITHUB_TOKEN=<token>
sudo systemctl start gtnh-daily-bootstrap.service
sudo systemctl unset-environment GITHUB_TOKEN
```

For permanent unattended bootstrap on a brand-new host, add an environment file or systemd credential outside git and extend the service to read it; do not commit the token.

After downloads complete, check status and logs:

```sh
systemctl status gtnh-daily-bootstrap.service
systemctl status gtnh-daily-server.service
sudo journalctl -u gtnh-daily-bootstrap.service -n 200 --no-pager
sudo journalctl -u gtnh-daily-server.service -n 200 --no-pager
```

Good signs are: bootstrap exited successfully, the server service is active/running, and logs show the Minecraft server starting instead of repeated missing-file or download errors.

If a world backup exists, restore the backup contents so the world folder is exactly:

```text
/var/lib/gtnh-daily/server/World
```

Stop the server before replacing a world. After copying/extracting the backup, ensure ownership:

```sh
sudo chown -R gtnh-daily:gtnh-daily /var/lib/gtnh-daily/server/World
```

A valid world backup should contain Minecraft world files such as `level.dat`, region/dimension folders, player data, and mod data.

## Client from scratch

Close Prism/Minecraft first, then run:

```sh
gtnh-daily-client-sync
```

This bootstraps the Prism instance if missing, installs declared packs, and updates against the server-published manifest. The command should be run as the normal desktop user because Prism files live in that user's home directory.

Override the SSH host when needed. `nemesis` is already the default in this repo, so this example is mainly a template for replacing it with another host:

```sh
GTNH_DAILY_SERVER=nemesis gtnh-daily-client-sync
```

Then launch the Daily desktop entry or:

```sh
prismlauncher --launch "GT New Horizons (Daily)" --server localhost:25566
```

If the server is remote and not already available at `localhost:25566`, create an SSH tunnel in another terminal before launching:

```sh
ssh -N -L 25566:localhost:25566 nemesis
```

## Routine operations

Manual server update starts the update service immediately instead of waiting for the daily timer. It may stop/restart the Daily server, so do not run it while players are online unless that interruption is acceptable.

```sh
sudo systemctl start gtnh-daily-update.service
sudo journalctl -u gtnh-daily-update.service -n 200 --no-pager
```

Check logs for backup creation, updater success, manifest publication, and server restart.

Manual client sync:

```sh
gtnh-daily-client-sync
journalctl --user -u gtnh-daily-client-sync.service -n 200 --no-pager
```

Rollback without an argument uses the latest pre-update backup:

```sh
sudo gtnh-daily-rollback
```

Rollback stops the Daily server and replaces the server directory from backup. It does not automatically roll back clients; run client sync carefully afterward if the server manifest changed.

Restore only the active world from the latest in-instance FTBUtilities/ServerUtilities zip backup:

```sh
sudo gtnh-daily-ftbu-rollback
```

To restore a specific in-instance zip backup instead:

```sh
sudo gtnh-daily-ftbu-rollback /var/lib/gtnh-daily/server/backups/2026-06-20-14-46-50.zip
```

This stops the Daily server, reads the active world name from `server.properties`, validates that the zip contains that world with `level.dat`, moves aside each top-level path present in the zip, extracts those paths into the server directory, fixes ownership, and starts the server again. This preserves ServerUtilities/FTBUtilities additional backup paths such as `journeymap`, `TCNodeTracker`, NEI saves, or `visualprospecting` when they are included in the zip.

## Safety guarantees

The bootstrap/update flow is designed to be idempotent:

- missing instances are created;
- existing instances are not re-extracted from artifacts;
- declared updater extras/excludes are reconciled;
- server EULA and port policy are enforced;
- client resource/shader pack files are downloaded, hash-verified, and refreshed when needed;
- client update refuses to run while Prism/Minecraft is active;
- server updates back up before mutation and restart only if previously active.

The flow is not a world backup system. Keep world backups separately if the world must survive a wipe. A good world-backup plan should copy `/var/lib/gtnh-daily/server/World` while the server is stopped or from a storage-level snapshot known to be consistent.
