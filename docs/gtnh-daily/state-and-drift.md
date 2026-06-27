# Live state and drift captured

This file records the important non-world state discovered from the live Daily server and Prism client during the 2026-06 setup/review. It is a snapshot of what was found and why it was declared in Nix. Daily versions will move forward over time, so historical version strings here are evidence, not a requirement to stay on that exact version.

“Live state” means files that existed on disk before this cleanup. “Drift” means those files differed from what the repo previously declared or documented.

## Server updater state

`/var/lib/gtnh-daily/server/.gtnh-daily-updater.json` showed:

- side: `server`;
- mode: `daily`;
- config version: `2.9.0-nightly-2026-06-13-03` at inspection time;
- excluded mods: `JourneyMap Server`;
- extra mods:
  - `GTNH-Web-Map` from `github:GTNewHorizons/GTNH-Web-Map`, match `^gtnh-web-map-.*[0-9]\.jar$`, side `SERVER`;
  - `MineMenu` from `modrinth:mine-menu/HNivj4HD`, side `SERVER`.

These entries are now declared in `nix/modules/gtnh-daily-server.nix` and reconciled by bootstrap/update service pre-start logic.

## Client updater state

`~/.local/share/PrismLauncher/instances/GT New Horizons (Daily)/.gtnh-daily-updater.json` showed:

- side: `client`;
- mode: `daily`;
- extra mods:
  - `JourneyMap` from `github:TeamJM/journeymap-legacy`, match `unlimited\.jar$`, side `CLIENT`;
  - `MineMenu` from `modrinth:mine-menu/HNivj4HD`, side `CLIENT`.

These entries are now declared in `nix/modules/prismlauncher.nix` and reconciled by `gtnh-daily-client-bootstrap`.

## Mod jar difference highlights

Server-only jars included:

- `gtnh-web-map-0.4-beta-1.jar` — declared as the `GTNH-Web-Map` extra;
- `Morpheus-1.7.10-1.6.21.jar` — a server-side sleep/vote helper found in the pack/server state.

Client-only jars included expected client-side/render/UI mods such as:

- Angelica — rendering/performance/shader support;
- CraftPresence — Discord rich presence;
- JourneyMap Unlimited — minimap/world-map client;
- MouseTweaks — inventory mouse interaction helper;
- Schematica — client-side build schematic helper;
- ToroHealth — client-side health display;
- resource/loading helpers and other client-only GTNH components.

An “ad hoc jar copy” means manually dropping a jar into `mods/` without telling the updater. The updater state, not manual jar copies, is the source of truth for extra/excluded managed mods.

## Resource and shader packs

Client selected resource packs were read from:

```text
~/.local/share/PrismLauncher/instances/GT New Horizons (Daily)/.minecraft/options.txt
```

The `resourcePacks:[...]` line is Minecraft's syntax for the enabled resource-pack list. The names in the list are directory names inside `.minecraft/resourcepacks`:

```text
resourcePacks:["AE2-Dark-Mode.v.1.18","shadowui","Modernity-GTNH-main"]
```

Custom resource pack/shader pack state captured into declarative config:

- `AE2-Dark-Mode.v.1.18.zip` URL/hash;
- `Shadow.UI.v5.30-Modernity.version.zip` URL/hash;
- `Modernity-GTNH-main.zip` URL/hash;
- `ComplementaryReimagined_r5.8.1.zip` URL/hash;
- `ComplementaryUnbound_r5.8.1.zip` URL/hash;
- `ComplementaryUnbound_r5.8.1.zip.txt` text contents.

The large zip files are intentionally not tracked in git; bootstrap downloads and verifies them.

## Config drift

The updater tracks config with `.gtnh-configs`. Both server and client had many config differences relative to their tracked pack refs. That means files under `config/` differed from the updater's remembered pack baseline.

Those differences can be generated/new config files from mods, migrated pack config changes, or local edits. Copying the entire config tree into Nix would freeze lots of runtime noise and make future pack config merges harder. For reproducibility, we rely on the updater's config-git merge model plus declared extras/excludes/bootstrap rather than copying the entire mutable config tree into Nix.

The explicit config policy we currently enforce in Nix is:

- server port is rewritten to `25566` on every start;
- EULA is accepted during bootstrap;
- updater extras/excludes are reconciled;
- client resource pack selection is set in `options.txt` when that file exists.

Manual local config overrides applied on 2026-06-27:

- `config/GregTech/Pollution.cfg`: `B:"Activate Pollution"=false` on both server and Daily Prism client;
- `config/bogosorter.cfg`: `I:dropoffRadius=16` on both server and Daily Prism client.

These overrides are live mutable config edits, not declarative Nix policy yet. The updater's config merge normally preserves local edits, but a future pack config conflict may overwrite them because the updater merges pack config changes with pack-side conflict preference. To make these settings reproducible, add a targeted post-bootstrap/post-update config patch step rather than symlinking whole config files from the Nix store.

World data, logs, generated maps, backups, caches, and runtime/player files were intentionally excluded.
