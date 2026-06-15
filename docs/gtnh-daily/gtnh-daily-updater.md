# `gtnh-daily-updater`

For definitions of updater, init, update, extras, excludes, regexes, config git repos, and source types, see [glossary.md](./glossary.md).

## Purpose

`gtnh-daily-updater` is the tool that updates an existing GTNH Daily or Experimental instance. “Experimental” is another non-stable GTNH update mode; this repo uses Daily. The updater is not a general installer for a missing instance: it expects server/client files to already exist, then initializes state by scanning those files.

It handles:

- manifest-based mod additions/removals/updates;
- excluded manifest mods;
- extra mods from the GTNH assets database, GitHub releases, CurseForge, Modrinth, or direct URLs;
- Prism/MultiMC versus server directory layout;
- config updates through a local git repository;
- download caching;
- optional profile-based batch updates.

## Local state

Each instance has:

```text
<instance-dir>/.gtnh-daily-updater.json
```

Important fields:

- `side` — `client` or `server`.
- `mode` — `daily` or `experimental`.
- `manifest_date` — applied manifest timestamp; empty after init so the first update runs.
- `config_version` — config version the updater believes is applied.
- `mods` — tracked mod names and installed filenames/versions.
- `exclude_mods` — manifest mod names skipped during updates.
- `extra_mods` — additional mod specs or same-name manifest overrides.

The updater preserves extras/excludes across `init`, so our bootstrap can initialize first and then reconcile the declarative extras/excludes. In this repo, Nix is the source of truth for those two fields; manual changes to them can be overwritten by the next bootstrap/update.

## Init

`init` requires an existing instance and a correct config version:

```sh
gtnh-daily-updater init --instance-dir <dir> --side client|server --config <version>
```

During init it:

1. fetches the GTNH assets database;
2. resolves the game directory (`.minecraft` for Prism/MultiMC clients, root for servers);
3. backs up `mods/` to `.gtnh-mods-backup-YYYY-MM-DD`;
4. scans installed jars and matches them to assets/manifest entries;
5. removes jars for already-declared excludes;
6. initializes `.gtnh-configs` if git is available;
7. writes `.gtnh-daily-updater.json`.

## Update

`update` loads local state, resolves the manifest/assets database, canonicalizes mod names, computes a mod diff, downloads needed jars, removes obsolete jars, updates LWJGL3ify if needed, merges config updates, and persists the new state.

Config merge behavior uses `<game-dir>/.gtnh-configs` on the `local` branch. That directory is a local git repository used by the updater to remember pack config versions and merge new pack config changes. Pack config versions are represented as git refs/tags. Updates merge with `-X theirs`, meaning pack changes win on direct conflicts while local edits are generally preserved when they do not conflict.

## Extras

Extras are declared by name. Sources can be:

- empty source: GTNH assets database lookup;
- `github:Owner/Repo` plus optional `--match` regex for selecting a release asset;
- `curseforge:project` or `curseforge:project/file`;
- `modrinth:project` or `modrinth:project/version`;
- direct `http(s)` URL.

A same-name extra overrides a manifest entry. We use this for client JourneyMap: the manifest provides FairPlay JourneyMap, while our client extra named `JourneyMap` selects the unlimited jar from `github:TeamJM/journeymap-legacy`. The `--match` regex chooses the release asset whose filename ends with `unlimited.jar`.

## Excludes

Excludes are manifest mod names skipped during updates. We exclude `JourneyMap Server` on the server because the private server uses JourneyMap Unlimited on clients and does not need the server-side FairPlay component. If it were not excluded, the updater could reinstall the server-side FairPlay jar during updates.

## Our desired updater state

Server:

- exclude `JourneyMap Server`;
- extra `GTNH-Web-Map` from `github:GTNewHorizons/GTNH-Web-Map`, matched by `^gtnh-web-map-.*[0-9]\.jar$`;
- extra `MineMenu` from `modrinth:mine-menu/HNivj4HD`, where `HNivj4HD` is the exact Modrinth version/file id.

Client:

- extra `JourneyMap` from `github:TeamJM/journeymap-legacy`, matched by `unlimited\.jar$`;
- extra `MineMenu` from `modrinth:mine-menu/HNivj4HD`, where `HNivj4HD` is the exact Modrinth version/file id.

## Local patch

Upstream normally fetches the latest manifest at update time. We patch the tool with `--manifest-file` because exact client/server matching needs a saved manifest file, not “whatever is latest right now.” The server can update against a downloaded manifest file and clients can update against the exact server-published manifest.

The patch:

- adds the CLI flag;
- expands `~` in the flag;
- adds `ManifestFile` to updater options;
- loads JSON from that file when present;
- still fetches the assets database normally;
- preserves upstream behavior when the flag is absent.
