# GTNH Daily reproducible setup

This folder is the from-scratch reference for our GT New Horizons Daily deployment.

In plain language: **GTNH Daily** is a frequently rebuilt test/development version of the GT New Horizons Minecraft modpack. This repo uses Nix/NixOS/Home Manager to recreate the Daily server and the matching Prism Launcher client after a rebuild or disk wipe. It recreates the pack files, updater state, services, timers, launchers, resource packs, and shader packs. It does **not** recreate the Minecraft world unless you restore a separate world backup.

The main goal is: after a drive wipe and rebuild, mutable world data aside, the Daily server and Prism client can be recreated, updated to the same exact server-published manifest, and used to join the server once downloads complete.

## If you just want to play

1. Make sure the Daily server is running or reachable through an SSH tunnel.
2. Close Prism/Minecraft.
3. Run `gtnh-daily-client-sync` as your normal user, not with `sudo`.
4. Launch the `GT New Horizons (Daily)` desktop entry.

If the server is remote and the desktop entry expects `localhost:25566`, run this in another terminal first:

```sh
ssh -N -L 25566:localhost:25566 nemesis
```

## If you administer the server

1. Check `gtnh-daily-bootstrap.service` after rebuild; it creates missing server files.
2. Check `gtnh-daily-server.service`; it runs the Minecraft server on port `25566`.
3. Check `gtnh-daily-update.timer`; it schedules Daily updates.
4. Keep separate backups of `/var/lib/gtnh-daily/server/World` if the world must survive disk loss.

## Read in this order

1. [glossary.md](./glossary.md) — plain-language definitions for Minecraft, Linux, systemd, Nix, and updater terms.
2. [concepts.md](./concepts.md) — Minecraft/Forge/GTNH concepts and file layout.
3. [daily-builds.md](./daily-builds.md) — GTNH Daily artifacts, manifests, and why client/server pinning matters.
4. [gtnh-daily-updater.md](./gtnh-daily-updater.md) — updater behavior, state, extras/excludes, config git repo, and our patch.
5. [server.md](./server.md) — NixOS server user, paths, services, bootstrap, update, rollback, firewall, and world-data boundary.
6. [client.md](./client.md) — Prism Launcher instance, bootstrap, client sync, resource packs, shader packs, desktop entries, and user timer.
7. [state-and-drift.md](./state-and-drift.md) — what we found on the live server/client and how it maps to declarative config.
8. [recovery.md](./recovery.md) — wipe/rebuild flow and operational recovery notes.
9. [implementation-notes.md](./implementation-notes.md) — guide for reading the Nix modules and generated shell/Python scripts.

`docs/games/gtnh-daily.md` is the older long-form administration/history record. Start here instead unless you need historical migration notes.
