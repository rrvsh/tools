# GTNH Daily builds, artifacts, and manifests

For definitions of GitHub Actions, artifacts, manifests, SHA-256, and tokens, see [glossary.md](./glossary.md).

## Source of Daily builds

GTNH Daily builds are produced by the `GTNewHorizons/DreamAssemblerXXL` GitHub Actions workflow `daily-modpack-build.yml`. GitHub Actions is GitHub's build automation; this workflow assembles GTNH Daily packages. They are not normal stable GitHub releases from `GT-New-Horizons-Modpack`.

The workflow publishes artifacts whose names follow this pattern:

- `GTNH-daily-YYYY-MM-DD+NNN-server-java17-25.zip` — dedicated server bootstrap files.
- `GTNH-daily-YYYY-MM-DD+NNN-mmcprism-java17-25.zip` — Prism/MultiMC client bootstrap files.
- `gtnh-daily-YYYY-MM-DD+NNN-manifest.json` — build manifest; includes the config version.
- `daily-build-bundle` — convenience bundle.

Artifacts can expire, meaning GitHub may delete old downloadable build files. Our bootstrap scripts therefore search recent successful workflow runs and choose a run with non-expired required artifacts. If GitHub requires authenticated artifact download or rate-limit help, provide `GITHUB_TOKEN` in the service/user environment. Recovery examples show how to set it temporarily.

## Published latest manifest

Normal updates use the published Daily manifest URL:

```text
https://raw.githubusercontent.com/GTNewHorizons/DreamAssemblerXXL/master/releases/manifests/daily.json
```

This manifest is the current latest Daily metadata. It records pack version information, the config version, timestamp, and selected mods. “Selected mods” means the exact mod entries the Daily build expects for that side/version.

## Why the server publishes its applied manifest

If the server updated directly from the latest remote manifest and the client later independently updated from the latest remote manifest, the client could accidentally advance beyond the server if a newer Daily appeared between the two operations. “Advance beyond the server” means the client installs a newer/different mod set than the server is running, which can cause join failures or mod mismatch errors.

To prevent this, our server update flow:

1. downloads the current Daily manifest into a temporary file;
2. updates the server using that exact local file;
3. publishes that exact file to `/var/lib/gtnh-daily/current-manifest.json`;
4. writes `/var/lib/gtnh-daily/current-manifest.sha256`.

The client sync flow then fetches those two files from the server over SSH and updates against the same pinned manifest. This keeps client and server coherent: both sides use the same intended mod/config metadata.

## Bootstrap versus update

Initial bootstrap requires a full artifact because `gtnh-daily-updater init` needs an existing instance to scan. The updater is not a from-nothing installer; it records what is already present, then can update it. After that, updates can use `gtnh-daily-updater update` plus the manifest.

Our server bootstrap creates the initial server files from a server artifact only when the expected launch files are missing. Our client bootstrap creates the Prism instance from a client artifact only when `.minecraft` is missing. Re-running bootstrap is therefore idempotent and does not clobber an already-created instance.
