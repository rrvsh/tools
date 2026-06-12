# GT New Horizons daily

This repo configures the daily server service/update loop. First bootstrap still has manual pieces because Daily build artifacts are GitHub Actions artifacts that require GitHub authentication.

References:

- GTNH wiki [Dev Builds](https://wiki.gtnewhorizons.com/wiki/Dev_Builds): Daily builds come from `GTNewHorizons/DreamAssemblerXXL` workflow `daily-modpack-build.yml`.
- [`gtnh-daily-updater` README](https://github.com/Caedis/gtnh-daily-updater): update Daily-to-Daily or Experimental-to-Experimental only, pass the correct current config version to `init`, and make a full backup before first use.

## Paths

- Prism instance: `~/.local/share/PrismLauncher/instances/GT New Horizons (Daily)`
- Server root: `/var/lib/gtnh-daily/server`
- Server backups: `/var/lib/gtnh-daily/backups`
- Server port: `25566`

The existing stable server under `/srv/gtnh` remains separate.

## Client Prism instance

Observed drag-and-drop import of `GTNH-daily-2026-06-12+569-mmcprism-java17-25.zip` into Prism created:

- `instance.cfg` with `InstanceType=OneSix`, `name=GT New Horizons (Daily)`, and `iconKey=gtnh_icon`
- `mmc-pack.json` with Minecraft/LWJGL3/Forge/LWJGL3ify components
- component patches under `patches/`
- game files under `.minecraft/`, including `mods/`, `config/`, `resourcepacks/`, and `serverutilities/`
- LWJGL3ify forge patch jar under `libraries/`

The Nix config only adds a desktop entry for this instance. If initializing this client with `gtnh-daily-updater`, use the outer Prism instance directory as `--instance-dir`, not `.minecraft`.

## Download Daily artifacts

List recent successful Daily runs:

```sh
gh run list \
  -R GTNewHorizons/DreamAssemblerXXL \
  -w daily-modpack-build.yml \
  --limit 10
```

Inspect artifacts for a run:

```sh
gh run view <run-id> -R GTNewHorizons/DreamAssemblerXXL
gh api repos/GTNewHorizons/DreamAssemblerXXL/actions/runs/<run-id>/artifacts \
  --jq '.artifacts[] | [.name,.size_in_bytes,.expired] | @tsv'
```

Expected names include:

```text
GTNH-daily-YYYY-MM-DD+NNN-mmcprism-java17-25.zip
GTNH-daily-YYYY-MM-DD+NNN-server-java17-25.zip
gtnh-daily-YYYY-MM-DD+NNN-manifest.json
```

Download the server artifact and manifest:

```sh
gh run download <run-id> \
  -R GTNewHorizons/DreamAssemblerXXL \
  -n GTNH-daily-YYYY-MM-DD+NNN-server-java17-25.zip \
  -n gtnh-daily-YYYY-MM-DD+NNN-manifest.json \
  --dir /tmp/gtnh-daily-bootstrap
```

`gh run download` extracts each artifact into a directory named after the artifact. The server contents should be copied from that directory into `/var/lib/gtnh-daily/server`.

The updater `--config` value is the manifest JSON `config` field, for example:

```json
{ "config": "2.9.0-nightly-2026-06-12" }
```

## Bootstrap the server

After applying the Nix config, copy the server artifact contents and initialize updater state:

```sh
sudo cp -a /tmp/gtnh-daily-bootstrap/GTNH-daily-YYYY-MM-DD+NNN-server-java17-25.zip/. \
  /var/lib/gtnh-daily/server/
sudo chown -R gtnh-daily:gtnh-daily /var/lib/gtnh-daily
sudo -u gtnh-daily env HOME=/var/lib/gtnh-daily \
  XDG_CACHE_HOME=/var/lib/gtnh-daily/cache \
  XDG_CONFIG_HOME=/var/lib/gtnh-daily/config \
  PATH=/run/current-system/sw/bin \
  gtnh-daily-updater init \
  --instance-dir /var/lib/gtnh-daily/server \
  --side server \
  --config <manifest-config-field>
sudo sed -i 's/^eula=false/eula=true/' /var/lib/gtnh-daily/server/eula.txt
```

The server service rewrites `server-port=25566` in `server.properties` before startup.

## Operations

Start the server:

```sh
sudo systemctl start gtnh-daily-server.service
```

Run an update immediately:

```sh
sudo systemctl start gtnh-daily-update.service
```

The update service:

1. Stops only `gtnh-daily-server.service`.
2. Creates `/var/lib/gtnh-daily/backups/pre-update-<timestamp>.tar.zst`.
3. Runs `gtnh-daily-updater update --instance-dir /var/lib/gtnh-daily/server` as `gtnh-daily` with `git` on `PATH`.
4. Restarts the daily server only if it was active before the update.

The timer uses `Persistent=true`, so missed scheduled updates run after the system comes back online.

## Rollback

Latest backup:

```sh
sudo gtnh-daily-rollback
```

Specific backup:

```sh
sudo gtnh-daily-rollback /var/lib/gtnh-daily/backups/pre-update-YYYYmmdd-HHMMSS.tar.zst
```

Rollback stops only the daily server, moves the current server to `server.rollback-<timestamp>`, extracts the selected backup, fixes ownership, and starts the daily server.
