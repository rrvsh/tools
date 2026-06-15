# Client and Prism Launcher

For definitions of Prism, Home Manager, SSH, resource packs, shader packs, and other terms, see [glossary.md](./glossary.md). For implementation details, see [implementation-notes.md](./implementation-notes.md).

## Prism Launcher

Prism Launcher manages Minecraft instances: separate installed copies of Minecraft/modpacks. Our Home Manager module installs Prism with JDK 25 available because GTNH Daily Java 17-25 builds are intended for modern Java/LWJGL3ify use. In practice that means Prism can launch this old Minecraft pack using a modern Java runtime.

The Daily instance name is exactly this. The name matters because the desktop entry and sync scripts use it in commands and paths:

```text
GT New Horizons (Daily)
```

The instance directory is:

```text
~/.local/share/PrismLauncher/instances/GT New Horizons (Daily)
```

The game directory is:

```text
~/.local/share/PrismLauncher/instances/GT New Horizons (Daily)/.minecraft
```

## Desktop entries

A desktop entry is the launcher icon/menu item shown by a desktop environment. Home Manager declares:

- a stable GTNH desktop entry for `GT_New_Horizons_2.8.4_Java_17-25`;
- a Daily desktop entry that launches `GT New Horizons (Daily)` and passes `--server localhost:25566`.

`--server localhost:25566` asks Prism/Minecraft to connect to a server on this machine at port `25566` after launch. If an SSH tunnel is running, that local port is forwarded to the remote server.

The Daily entry assumes the server is reachable locally or through whatever networking/SSH forwarding makes `localhost:25566` valid. For a remote server named `nemesis`, one simple tunnel is `ssh -N -L 25566:localhost:25566 nemesis`.

## Client bootstrap

`gtnh-daily-client-bootstrap` is installed on Linux Home Manager systems. Close Prism/Minecraft before running it; the command refuses to mutate the instance while the game appears active. It is idempotent and does the following:

1. reads `/var/lib/gtnh-daily/current-manifest.sha256` from the server over SSH, so passwordless SSH to the server host must work;
2. copies `/var/lib/gtnh-daily/current-manifest.json` with `scp`;
3. verifies the copied manifest against the server hash;
4. creates the Prism instance from a recent non-expired `mmcprism-java17-25` artifact if `.minecraft` is missing;
5. extracts the manifest config version;
6. runs `gtnh-daily-updater init --side client` if updater state is missing;
7. reconciles declared client extra mods into `.gtnh-daily-updater.json`;
8. installs declared resource pack and shader pack files;
9. unpacks the resource packs whose active names are directories;
10. writes the active `resourcePacks:` line in `options.txt` when the file exists.

If SSH is not configured, bootstrap fails before changing the instance. If `.minecraft` already exists but is broken or incomplete, bootstrap does not overwrite it; move the broken instance aside after backing up anything important, then rerun bootstrap/sync.

The bootstrap defaults to SSH host `nemesis`, the server hostname used by this repo. Override with:

```sh
GTNH_DAILY_SERVER=<host> gtnh-daily-client-bootstrap
```

## Client sync

`gtnh-daily-client-sync` is the normal update command. It:

1. takes a user lock under `~/.cache/gtnh-daily-client-sync`;
2. refuses to run if Prism/Minecraft appears active;
3. runs the client bootstrap first, so a missing client can be created;
4. exits early if the local applied hash equals the server hash;
5. copies and verifies the server manifest;
6. creates a full instance backup under `~/.local/share/PrismLauncher/backups`;
7. runs `gtnh-daily-updater update --manifest-file <server-manifest>`;
8. records the server hash locally.

The user timer runs hourly with a 15 minute randomized delay and `Persistent=true`. If the timer fires while Prism/Minecraft is open, the sync command refuses to change files and exits. Logs are visible with `journalctl --user -u gtnh-daily-client-sync.service`.

Backups are full directory copies under `~/.local/share/PrismLauncher/backups`. They can be large, and this script does not prune old backups automatically.

## Resource packs

A resource pack changes client-side textures, models, sounds, or UI. It does not change server gameplay. The live client had these selected resource packs:

```text
AE2-Dark-Mode.v.1.18
shadowui
Modernity-GTNH-main
```

The repo does not store these zip files because large binary assets make git history heavy and are harder to review. Instead, `nix/modules/prismlauncher.nix` declares each download URL and SHA-256 hash. Bootstrap downloads the files into `.minecraft/resourcepacks` when missing or when the local copy has the wrong hash. It then unpacks the zips into the directory names used by `options.txt`, because Minecraft enables these packs by directory name.

Declared resource pack downloads:

- `AE2-Dark-Mode.v.1.18.zip` from `Ranzuu/AE2-Dark-Mode`;
- `Shadow.UI.v5.30-Modernity.version.zip` from `Ranzuu/Shadow-UI`;
- `Modernity-GTNH-main.zip` from a pinned `ModernityGTNH/Modernity-GTNH` commit archive.

The GTNH-provided resource pack zips that come with the pack also remain present after artifact/bootstrap/update; our declared packs add the current custom selection on top.

## Shader packs

A shader pack changes client-side graphics such as lighting, shadows, and color. Shader packs are handled the same way as resource packs: URLs and hashes are declared in Nix, and bootstrap downloads them into `.minecraft/shaderpacks`.

Declared shader pack downloads:

- `ComplementaryReimagined_r5.8.1.zip` from Modrinth;
- `ComplementaryUnbound_r5.8.1.zip` from Modrinth.

Bootstrap also writes the small `ComplementaryUnbound_r5.8.1.zip.txt` option sidecar because it is plain text, not a large binary asset. The sidecar stores Complementary Unbound settings such as light color multipliers/night brightness. Shader selection itself is normally local/client preference; the files are what matters for being able to select/use the same shaders after rebuild.
