# GTNH pack build pipeline

This page records how GTNH's upstream pack artifacts are produced, focusing on the two repos that matter to this Nix setup:

- [`GTNewHorizons/GT-New-Horizons-Modpack`](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack) — the pack config/scripts/resource tree;
- [`GTNewHorizons/DreamAssemblerXXL`](https://github.com/GTNewHorizons/DreamAssemblerXXL) — the assembler that turns config releases plus mod releases into client/server archives and Daily manifests. DreamAssemblerXXL describes itself as the replacement for DreamMasterXXL.

## Source roles

`GT-New-Horizons-Modpack` is not the full distributable by itself. Its tag workflow says it builds and releases “a zip of the modpack config and script files,” and the workflow creates that zip by archiving the repo while excluding `.git`, `.github`, `release/`, and `changelog.py` ([release-tags.yml](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/blob/1eeb284e6edc6d2278535ca8a66277038b71f2d7/.github/workflows/release-tags.yml#L1-L8), [release-tags.yml](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/blob/1eeb284e6edc6d2278535ca8a66277038b71f2d7/.github/workflows/release-tags.yml#L61-L67)). For nightly-tagged config releases, it also downloads a matching `GTNH-Guide-Pack` zip into `resourcepacks/`; Daily tags choose the newest non-`-pre` guide release, while experimental tags choose the newest guide release of any tag ([release-tags.yml](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/blob/1eeb284e6edc6d2278535ca8a66277038b71f2d7/.github/workflows/release-tags.yml#L26-L55)).

`DreamAssemblerXXL` treats that config repo as one versioned asset: `CONFIG_REPO_NAME = "GT-New-Horizons-Modpack"` ([gtnh_config.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/models/gtnh_config.py#L1-L7)). Its README says `gtnh-assets.json` lists pack mods/assets and `releases/` contains manifests for official versions; it also names the key commands, including `generate_daily.py`, `assemble_release.py`, and assembler modules ([README.md](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/README.md#L3-L28)).

## Main config repo release flow

When a tag is pushed to `GT-New-Horizons-Modpack`:

1. GitHub Actions checks out the repo and derives `RELEASE_VERSION` from the tag ref ([release-tags.yml](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/blob/1eeb284e6edc6d2278535ca8a66277038b71f2d7/.github/workflows/release-tags.yml#L19-L24)).
2. If the tag name contains `-nightly-`, the workflow bundles a `GTNH-Guide-Pack` release into `resourcepacks/` before zipping ([release-tags.yml](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/blob/1eeb284e6edc6d2278535ca8a66277038b71f2d7/.github/workflows/release-tags.yml#L26-L55)).
3. It creates `release/<tag>.zip` from the repository contents, excluding GitHub metadata and transient release files ([release-tags.yml](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/blob/1eeb284e6edc6d2278535ca8a66277038b71f2d7/.github/workflows/release-tags.yml#L57-L67)).
4. It publishes that zip under the same tag as a GitHub release asset ([release-tags.yml](https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/blob/1eeb284e6edc6d2278535ca8a66277038b71f2d7/.github/workflows/release-tags.yml#L69-L76)).

DreamAssemblerXXL later downloads this config zip as the release's `config` asset and unpacks it into generated client/server archives.

## Daily build flow in DreamAssemblerXXL

The Daily workflow runs manually or every day at 03:20 UTC, cancels older in-progress runs, checks out `master`, installs Python 3.11 via `uv`, and restores a weekly `cache/` of mod zips ([daily-modpack-build.yml](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/.github/workflows/daily-modpack-build.yml#L1-L59)). The actual build step is two commands:

```sh
uv run python -m daxxl.cli.generate_daily --id "$GITHUB_RUN_NUMBER" --update-available
uv run python -m daxxl.cli.assemble_daily
```

Those commands are in the workflow at [daily-modpack-build.yml lines 53-59](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/.github/workflows/daily-modpack-build.yml#L53-L59).

`generate_daily` loads the existing `daily` manifest, sets the Daily id from the workflow run number, calls `update_release("daily", update_available=True, last_version="previous_daily")`, then writes the new Daily manifest, stores the old Daily as `previous_daily`, and saves assets/modpack metadata ([generate_daily.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/cli/generate_daily.py#L14-L42)). With `update_available=True`, `update_release` refreshes available assets first, then uses the latest config asset and each enabled mod's latest version unless overrides/exclusions say otherwise ([modpack_manager.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/modpack_manager.py#L430-L540)).

`assemble_daily` reloads the new `daily` manifest, downloads all assets for it, then emits four archive variants: Java 17-25 server zip, Java 8 server zip, Java 8 Prism/MultiMC client zip, and Java 17-25 Prism/MultiMC client zip ([assemble_daily.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/cli/assemble_daily.py#L15-L35)). The download step fetches every manifest mod, the selected config zip, and translations into the cache ([modpack_manager.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/modpack_manager.py#L978-L1045)).

## What goes into the generated archives

The common assembler opens a target zip and adds mods, config, and a generated README/changelog ([generic_assembler.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/assembler/generic_assembler.py#L224-L250)). It computes the mod list by side, so client/server/java variants only include mods valid for that side ([generic_assembler.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/assembler/generic_assembler.py#L108-L116)).

Server zips place jars under `mods/`; for `lwjgl3ify` server builds, the assembler also pulls the `forgePatches.jar` extra asset into the archive root ([zip_assembler.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/assembler/zip_assembler.py#L58-L66)). Server config comes from the selected config zip, except excluded entries and old embedded `server.properties`; then server assets and a generated `server.properties` are added ([zip_assembler.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/assembler/zip_assembler.py#L75-L106), [zip_assembler.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/assembler/zip_assembler.py#L111-L142)).

Prism/MultiMC client zips are rooted at `GT New Horizons <version>/`. Mods go under `.minecraft/mods`, config zip contents go under `.minecraft/`, and any mod extra asset ending in `multimc.zip` is unpacked as launcher metadata/patches ([multi_poly.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/assembler/multi_poly.py#L48-L100)). The assembler then adds `instance.cfg`, the GTNH icon, and `mmc-pack.json` for Java 8 client archives; Java 9+/modern Java archives skip `mmc-pack.json` in that path ([multi_poly.py](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/src/daxxl/assembler/multi_poly.py#L127-L150)).

## Testing, artifact upload, and repository mutation

After building, the workflow renames the four generated archives to `GTNH-daily-<date>+<run>-...` names and bundles them with `releases/manifests/daily.json`, changelogs, and `gtnh-assets.json` for downstream jobs ([daily-modpack-build.yml](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/.github/workflows/daily-modpack-build.yml#L121-L150)). The test matrix unpacks both Java 25 and Java 8 server/client pairs, installs the client via `prism-bootstrap`, injects HeadlessNH and HorizonQA, starts the server, runs the client, and verifies both sides ([daily-modpack-build.yml](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/.github/workflows/daily-modpack-build.yml#L153-L349)).

Only after the `build` and `test` jobs succeed does the `upload` job publish the manifest and the four zip artifacts. It then commits the Daily changelog, `releases/manifests/daily.json`, and `gtnh-assets.json` back to `master` ([daily-modpack-build.yml](https://github.com/GTNewHorizons/DreamAssemblerXXL/blob/ae12decb6848ce49aacf88a7eeb7f2c2e2c78044/.github/workflows/daily-modpack-build.yml#L628-L690)).

## How this relates to our Nix Daily setup

Our server bootstrap/update logic consumes the DreamAssemblerXXL Daily products, not the raw config repo alone:

- the initial server bootstrap needs a full server archive because `gtnh-daily-updater init` scans an already-existing instance;
- subsequent server updates use DreamAssemblerXXL's `releases/manifests/daily.json` as the version source;
- our client sync fetches the server-published manifest so client and server update against the same exact Daily manifest.

The config files edited locally under `config/` ultimately originate from the `GT-New-Horizons-Modpack` config zip selected by the DreamAssemblerXXL manifest. Local mutable config edits can survive updater merges, but declarative local policy should be applied as targeted post-bootstrap/post-update patches rather than replacing the whole config tree.
