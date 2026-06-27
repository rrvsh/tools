# nix-horizons research handoff

Date: 2026-06-15

This file preserves the research context gathered so far for a future standalone project named **nix-horizons**.

The purpose of this handoff is to avoid redoing research. It intentionally contains only research pointers, source locations, findings, and follow-up directions.

## Project idea

`nix-horizons` is intended as a standalone Nix/flake project for Minecraft server infrastructure, with special interest in GT New Horizons / GTNH Daily style workflows later.

No repository structure or implementation is assumed by this file.

## Primary research questions already investigated

1. How does `itzg/docker-minecraft-server` support GTNH?
2. What does the official GTNH container setup recommend?
3. How does the nixpkgs NixOS `services.minecraft-server` module work?
4. What existing Nix flakes/modules exist for modded Minecraft servers?
5. Which existing projects are useful references, and which are not direct fits?

## Local paths with fetched/cloned research material

Several repositories were fetched under:

```text
/tmp/pi-github-repos
```

Important local paths:

```text
/tmp/pi-github-repos/itzg/docker-minecraft-server
/tmp/pi-github-repos/Infinidoge/nix-minecraft
/tmp/pi-github-repos/mkaito/nixos-modded-minecraft-servers
/tmp/pi-github-repos/aster-void/nix-mc
/tmp/pi-github-repos/TLATER/nix-minecraft-servers
/tmp/pi-github-repos/jyooru/nix-minecraft-servers
/tmp/pi-github-repos/Ninlives/minecraft.nix
/tmp/pi-github-repos/iamanaws/endernix
```

Local nixpkgs checkout used for module research:

```text
/home/rafiq/1_repos/nixpkgs
```

Relevant nixpkgs file:

```text
/home/rafiq/1_repos/nixpkgs/nixos/modules/services/games/minecraft-server.nix
```

Nixpkgs commit inspected:

```text
b5e9cca1667666e70abf6814c62dc0b1c759d7b1
```

## Web/source URLs researched

### itzg Docker Minecraft Server

Repository:

```text
https://github.com/itzg/docker-minecraft-server
```

Commit inspected:

```text
1a8844cb625d753409f02f3cfbd46eefd5c5d939
```

Important source files:

```text
https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/docs/types-and-platforms/mod-platforms/gtnh.md
https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-deployGTNH
https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-finalExec
https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-configuration
https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/examples/gtnh/docker-compose-type-gtnh.yaml
```

Documentation pages fetched/read:

```text
https://itzg-docker-minecraft-server.mintlify.app/configuration/environment-variables
https://itzg-docker-minecraft-server.mintlify.app/docker-compose
https://itzg-docker-minecraft-server.mintlify.app/mods-plugins/generic-packs
https://itzg-docker-minecraft-server.mintlify.app/mod-platforms/overview
```

### Official GTNH container setup

GTNH wiki page:

```text
https://wiki.gtnewhorizons.com/wiki/Server_Setup_(Container)
```

### nixpkgs Minecraft server module

Local file:

```text
/home/rafiq/1_repos/nixpkgs/nixos/modules/services/games/minecraft-server.nix
```

Equivalent GitHub URL at inspected commit:

```text
https://github.com/NixOS/nixpkgs/blob/b5e9cca1667666e70abf6814c62dc0b1c759d7b1/nixos/modules/services/games/minecraft-server.nix
```

### Nix/modded Minecraft projects

Infinidoge/nix-minecraft:

```text
https://github.com/Infinidoge/nix-minecraft
```

mkaito/nixos-modded-minecraft-servers:

```text
https://github.com/mkaito/nixos-modded-minecraft-servers
```

aster-void/nix-mc:

```text
https://github.com/aster-void/nix-mc
```

TLATER/nix-minecraft-servers:

```text
https://github.com/TLATER/nix-minecraft-servers
```

jyooru/nix-minecraft-servers:

```text
https://github.com/jyooru/nix-minecraft-servers
```

Ninlives/minecraft.nix:

```text
https://github.com/Ninlives/minecraft.nix
```

iamanaws/endernix:

```text
https://github.com/iamanaws/endernix
```

## Search queries already used

Useful prior search directions:

```text
itzg docker minecraft server GT New Horizons docker-minecraft-server docs environment variables mods modpacks
NixOS minecraft-server module nixpkgs services.minecraft-server declarative options
Nix flake modded Minecraft server GTNH Forge server NixOS examples
```

Additional targeted docs fetched for itzg:

```text
itzg docker minecraft server environment variables
itzg docker minecraft server docker compose
itzg docker minecraft server generic packs
itzg docker minecraft server mod platforms overview
```

## Key findings: itzg/docker-minecraft-server generally

`itzg/docker-minecraft-server` is a general-purpose Docker image for running Minecraft Java Edition servers.

General model:

1. Run a Docker container from `itzg/minecraft-server`.
2. Mount persistent server data at container path `/data`.
3. Configure with environment variables.
4. Startup scripts inspect env vars, download/install/update server files, write config, then launch Java.
5. Container filesystem is disposable; `/data` holds persistent world/config/modpack state.

Common core environment variables:

- `EULA=TRUE`: required.
- `TYPE`: server type, such as `VANILLA`, `PAPER`, `FORGE`, `FABRIC`, `SPIGOT`, `BUKKIT`, `CUSTOM`, or `GTNH`.
- `VERSION`: Minecraft version for normal server types.
- `MEMORY`, `INIT_MEMORY`, `MAX_MEMORY`: Java heap sizing.
- `UID`, `GID`: user/group IDs for file ownership inside mounted volumes.
- `TZ`: timezone.
- `DEBUG`: startup diagnostics.
- `SETUP_ONLY`: prepare files then stop before launching server.
- `FORCE_REDOWNLOAD`: force redownload for supported server types.
- `CUSTOM_SERVER`: URL/path for `TYPE=CUSTOM` server jar.

Docker Compose is the recommended operational form for persistent configuration. Compose examples commonly include:

- `image: itzg/minecraft-server:<tag>`
- `pull_policy: daily`
- `tty: true`
- `stdin_open: true`
- `ports: ["25565:25565"]`
- `environment: { EULA: "TRUE", TYPE: ..., MEMORY: ... }`
- `volumes: ["./data:/data"]`
- `restart: unless-stopped`

The image supports many modpack/mod platform workflows through `MODPACK_PLATFORM`, `TYPE`, or `MOD_PLATFORM`. Platforms include CurseForge, Modrinth, FTB, and GTNH.

Generic packs:

- `GENERIC_PACK`: one zip/tgz archive URL or container path.
- `GENERIC_PACKS`: multiple archive URLs/paths.
- `GENERIC_PACKS_PREFIX` and `GENERIC_PACKS_SUFFIX`: reduce repetition.
- `SKIP_GENERIC_PACK_UPDATE_CHECK`: skip expensive update checks.
- `FORCE_GENERIC_PACK_UPDATE`: force reapply.
- `SKIP_GENERIC_PACK_CHECKSUM`: skip expensive checksum generation.
- `GENERIC_PACKS_DISABLE_MODS`: disable selected mod filenames.

Generic packs are useful for arbitrary archive-based server content, including older modpack workflows.

## Key findings: itzg GTNH support

The itzg image has native GTNH support through:

```text
TYPE=GTNH
```

The GTNH support exists because GT New Horizons has specific deployment/update needs.

Important variables:

- `GTNH_PACK_VERSION`
  - default: `latest`
  - allowed values: `latest`, `latest-dev`, or a specific version like `2.8.1`
  - docs recommend a specific version for manual update control
- `GTNH_DELETE_BACKUPS`
  - default: `false`
- `SKIP_GTNH_UPDATE_CHECK`
  - default: `false`
  - if true, skips update checks
  - important caveat: if set before initial setup, it also prevents initial install

Official-style compose example shape:

```yaml
services:
  gtnh:
    image: itzg/minecraft-server:java25
    tty: true
    stdin_open: true
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      TYPE: GTNH
      GTNH_PACK_VERSION: "2.8.1"
      MEMORY: 6G
    volumes:
      - ./data:/data
    restart: unless-stopped
```

GTNH Java/resource guidance from docs:

- 2-4 CPU cores recommended.
- 6 GiB RAM baseline, more for players/progression.
- 20+ GiB storage.
- SSD recommended.
- Java 17+ recommended for performance.
- Java 25 recommended for GTNH 2.8.0+.

How `start-deployGTNH` selects a version:

- Fetches `https://downloads.gtnewhorizons.com/versions.json`.
- If `GTNH_PACK_VERSION=latest-dev`, selects latest entry titled `Beta release`.
- If `GTNH_PACK_VERSION=latest`, selects latest entry titled `Stable release`.
- Otherwise selects the exact version key.

How it selects server zip by Java version:

- Detects container Java version.
- Java 8 selects `.value.server.java8Url`.
- Java 17+ verifies the release supports that Java version, then selects `.value.server.java17_2XUrl`.
- Unsupported Java versions fail startup.

Install/update marker:

```text
/data/.gtnh-version
```

This stores the basename of the selected download URL. If missing or different, it installs/updates.

GTNH update behavior:

- Downloads selected server archive.
- Extracts it into a temporary directory.
- Replaces pack-managed directories such as:
  - `libraries`
  - `mods`
  - `resources`
  - `scripts`
- Deletes/replaces launch-related files such as:
  - `lwjgl3ify-forgePatches.jar`
  - `java9args.txt`
  - start scripts
  - Forge jar
  - server icon
- Backs up `config` to a timestamped `gtnh-upgrade-*` directory.
- Copies new config.
- Restores `config/JourneyMapServer` from backup if present.

GTNH defaults set by script:

- `ALLOW_FLIGHT=true`
- `LEVEL_TYPE=rwg`
- `DIFFICULTY=3`
- `ENABLE_COMMAND_BLOCK=true`
- `MOTD="Greg Tech New Horizons $GTNH_PACK_VERSION"`

GTNH launch behavior:

- Java 8:
  - `SERVER=/data/forge-1.7.10-10.13.4.1614-1.7.10-universal.jar`
- Java 17+:
  - `SERVER=/data/lwjgl3ify-forgePatches.jar`
  - appends `@java9args.txt`
- Always sets:
  - `VERSION=1.7.10`
  - `USES_MODS=true`
- Final args include:
  - `-Dfml.readTimeout=180`

Strengths:

- Strongest ready-made Docker path for GTNH stable/beta release servers.
- Officially documented and recommended in GTNH container guidance.
- Encodes GTNH-specific defaults and Java launch choices.
- Very practical for non-NixOS hosts or Docker-first deployments.

Limits to remember:

- The itzg GTNH path targets GTNH release downloads via `downloads.gtnewhorizons.com/versions.json`.
- It is not the same thing as a GitHub Actions Daily artifact workflow.
- Its update identity is `.gtnh-version`, not a manifest hash.
- It handles server deployment, not a matching Prism client workflow.

## Key findings: official GTNH container setup

The GTNH wiki container setup recommends the itzg Docker image for most container users.

Important points:

- Use `itzg/minecraft-server:java25` for current GTNH versions.
- Use `TYPE: GTNH`.
- Pin `GTNH_PACK_VERSION` to a specific version such as `2.8.1` for controlled updates.
- Mount persistent data at `/data`.
- Use `EULA: TRUE`.
- Allocate enough memory, commonly around `6G` or more.
- Optional whitelist/op/server settings can be expressed with image environment variables.

## Key findings: nixpkgs `services.minecraft-server`

File inspected:

```text
/home/rafiq/1_repos/nixpkgs/nixos/modules/services/games/minecraft-server.nix
```

Commit:

```text
b5e9cca1667666e70abf6814c62dc0b1c759d7b1
```

What it provides:

- A single NixOS Minecraft server service.
- System user/group `minecraft`.
- Persistent data directory, default `/var/lib/minecraft`.
- EULA generation/symlink.
- Optional declarative whitelist.
- Optional declarative `server.properties`.
- Firewall opening for server, RCON, and query ports.
- systemd socket/FIFO console input at `/run/minecraft-server.stdin`.
- journald logging.
- substantial systemd hardening.

Main options:

- `services.minecraft-server.enable`
- `services.minecraft-server.declarative`
- `services.minecraft-server.eula`
- `services.minecraft-server.dataDir`
- `services.minecraft-server.openFirewall`
- `services.minecraft-server.whitelist`
- `services.minecraft-server.serverProperties`
- `services.minecraft-server.package`
- `services.minecraft-server.jvmOpts`

Execution model:

```text
${cfg.package}/bin/minecraft-server ${cfg.jvmOpts}
```

Declarative mode behavior:

- Always symlinks generated `eula.txt`.
- If declarative mode is enabled, writes/symlinks `whitelist.json` and `server.properties`.
- On first switch to declarative mode, backs up existing stateful files with `.stateful` suffix.
- Creates a `.declarative` marker.

Hardening includes:

- `PrivateTmp`
- `PrivateUsers`
- `PrivateDevices`
- `ProtectHome`
- `ProtectKernelTunables`
- `ProtectKernelModules`
- `ProtectKernelLogs`
- `ProtectControlGroups`
- `ProtectClock`
- `ProtectHostname`
- `ProtectProc=invisible`
- `RestrictAddressFamilies`
- `RestrictNamespaces`
- `RestrictRealtime`
- `RestrictSUIDSGID`
- `UMask=0077`

Strengths:

- Very simple NixOS-native service.
- Good patterns for EULA, FIFO stdin, journald, firewall, and hardening.
- Good for vanilla or a prepackaged server derivation with `bin/minecraft-server`.

Limitations:

- Single server only.
- No modpack bootstrap/update logic.
- No Forge/GTNH-specific artifact handling.
- No old Forge 1.7.10 launch special cases.
- No client-side sync model.

## Key findings: Infinidoge/nix-minecraft

Repository:

```text
https://github.com/Infinidoge/nix-minecraft
```

This is the strongest modern Nix-native Minecraft server project found.

What it provides:

- Flake packages for many server families:
  - Vanilla
  - Fabric
  - Legacy Fabric
  - Quilt
  - Paper
  - Purpur
  - NeoForge
  - Velocity
- Tools such as:
  - `nix-modrinth-prefetch`
  - `fetchPackwizModpack`
  - `fetchModrinthModpack`
- NixOS module:
  - `services.minecraft-servers`
  - multiple named servers under `services.minecraft-servers.servers`

Notable module features:

- Global `enable`, `eula`, `openFirewall`, `dataDir`, `user`, `group`.
- Per-server `enable` and `autoStart`.
- Per-server package/JVM options.
- Per-server `serverProperties`.
- Whitelist/operators/bans.
- Stop/restart/reload hooks.
- Management system selection:
  - tmux
  - systemd socket/FIFO
- Environment-file support for secrets.
- Declarative `symlinks` and copied writable `files`.
- File generation in formats such as JSON/properties/text.
- Firewall port conflict assertions.
- Systemd hardening.

File model:

- `symlinks`: read-only Nix store paths linked into the server directory.
- `files`: copied into the server directory so they can be writable at runtime; removed/cleaned later.
- Managed paths are tracked in `.nix-minecraft-managed`.
- Existing unmanaged targets are backed up before replacement.

Packwiz model:

- `fetchPackwizModpack` can fetch a Packwiz pack and expose `mods`/`config` directories.
- Docs warn to use stable URLs such as tags/commits for reproducibility.

Strengths:

- Best general-purpose NixOS Minecraft server framework found.
- Good multi-server abstraction.
- Good declarative file model.
- Good secret/environment-file support.
- Good management and hardening patterns.

Limitations:

- No direct GTNH Daily semantics.
- No built-in old Forge 1.7.10 GTNH Daily artifact workflow.
- No `gtnh-daily-updater` integration.
- Still an excellent design reference.

## Key findings: mkaito/nixos-modded-minecraft-servers

Repository:

```text
https://github.com/mkaito/nixos-modded-minecraft-servers
```

What it provides:

- `services.modded-minecraft-servers`.
- Multiple modded Minecraft server instances.
- Per-instance users and directories, such as:
  - `/var/lib/mc-<name>`
  - user `mc-<name>`
- Declarative `server.properties`.
- EULA handling.
- Optional rsync access for operators.
- Port uniqueness assertions.
- Firewall opening.

Philosophy:

- It intentionally does not package/install modpacks.
- Operator places the server/modpack files in the state directory.
- The module runs `start.sh` from that directory.
- Nix provides `JVMOPTS`; the modpack start script decides how to use it.

Strengths:

- Simple multi-instance service framework.
- Honest about arbitrary modpack installation complexity.
- Useful per-instance user/state pattern.

Limitations:

- Not reproducible by itself after wipe unless something else populates the state directory.
- Older/pinned to NixOS 22.05 era.
- No GTNH-specific automation.

## Key findings: aster-void/nix-mc

Repository:

```text
https://github.com/aster-void/nix-mc
```

Commit inspected:

```text
458b4590d6b41f06a54397a819d7307fc7d63891
```

What it provides:

- NixOS module for:
  - Forge
  - NeoForge
  - Bedrock
- Multiple servers.
- `upstreamDir` for version-locked source directories.
- `symlinks` and copied writable files.
- Declarative `serverProperties`.
- Firewall handling.
- systemd hardening.
- tmux-based server process management.

Important note:

- Its README recommends `Infinidoge/nix-minecraft` for most users.
- `nix-mc` is useful when unsupported mod loaders or Bedrock are needed.

Strengths:

- Simple model: version-locked source + runtime data directory.
- Good if server files can be pinned as a flake input or fixed source tree.

Limitations:

- Assumes preexisting/version-locked server files.
- Does not solve arbitrary modpack updater workflows.

## Key findings: TLATER/nix-minecraft-servers

Repository:

```text
https://github.com/TLATER/nix-minecraft-servers
```

This repository is mostly a design/spec note, not a complete working implementation.

Important research value:

- Explains why Forge and modpack packaging are difficult in pure Nix.
- Forge installers download libraries as part of installation, which is impure.
- CurseForge/manifest-based packs may lack direct download URLs.
- Many server packs are arbitrary zip contents with custom scripts/installers.
- Purely packaging every modded server scenario is non-trivial.

Takeaway:

- Runtime bootstrap/update boundaries can be a pragmatic choice for complex old Forge modpacks.
- This is useful conceptual background even if the repo is not directly usable.

## Key findings: jyooru/nix-minecraft-servers

Repository:

```text
https://github.com/jyooru/nix-minecraft-servers
```

Commit inspected:

```text
48387fe72c74ad7b5bca624606f18d85e697022a
```

Findings:

- Older package set/flake for Minecraft servers.
- README says it is no longer maintained.
- Points users to `Infinidoge/nix-minecraft`.

Takeaway:

- Historical reference only.
- Prefer Infinidoge for this category.

## Key findings: Ninlives/minecraft.nix

Repository:

```text
https://github.com/Ninlives/minecraft.nix
```

Commit inspected:

```text
a0b850c5a1ca542026b594d14576bacddef6dfeb
```

What it provides:

- Nix packaging for vanilla/Fabric Minecraft client and server derivations.
- `withConfig` function for adding mods/resource packs/shader packs.
- Can run client/server derivations with Nix.

Limitations:

- More client/derivation oriented than NixOS server-service oriented.
- Server declarative option is documented as currently a no-op.

Takeaway:

- Useful for client/resource-pack ideas.
- Not a main server infrastructure base.

## Key findings: iamanaws/endernix

Repository:

```text
https://github.com/iamanaws/endernix
```

Commit inspected:

```text
05d1f2016f24660b2774ba907fff82824abbcb30
```

What it provides:

- Builds on `minecraft.nix`.
- Manages multiple isolated Minecraft installations/game directories.
- Focuses on client installations.
- Has Modrinth mod declaration and lockfile workflow.
- `mkInstance` supports name, version, loader, mods, resource packs, shader packs, JVM args, and extra config.

Takeaway:

- Useful inspiration for isolated client instance and Modrinth lockfile design.
- Not a server-service framework.

## Comparative conclusions

### Strongest ready-made Docker option

`itzg/docker-minecraft-server` with `TYPE=GTNH`.

Best when:

- Deployment target is Docker/container-first.
- Desired GTNH version is a stable/beta release from `downloads.gtnewhorizons.com/versions.json`.
- A compose-based operational model is acceptable.

### Strongest NixOS-native Minecraft framework

`Infinidoge/nix-minecraft`.

Best when:

- Need multiple Minecraft servers on NixOS.
- Server types are supported by its package set.
- Declarative files/symlinks and strong service management are valuable.

### Strongest simple upstream NixOS reference

nixpkgs `services.minecraft-server`.

Best when:

- Single server.
- Vanilla/prepackaged server.
- Need simple EULA/server.properties/FIFO/hardening/firewall behavior.

### Best conceptual warning

`TLATER/nix-minecraft-servers`.

Best for understanding why arbitrary Forge/modpack ecosystems are hard to package purely.

## Useful design ideas to reuse later

From itzg:

- Encode GTNH-specific defaults explicitly.
- Distinguish Java 8 vs Java 17+/25 launch paths.
- Use clear install/update marker files.
- Keep persistent data under a single well-known data directory.

From nixpkgs:

- systemd FIFO console input.
- journald logging.
- simple EULA assertion/generation.
- firewall handling from declared ports.
- strong systemd hardening.

From Infinidoge:

- Multi-server attrset model.
- `symlinks` for read-only declarative files.
- `files` for copied writable runtime files.
- environment-file support for secrets.
- managed-path marker file.
- backup unmanaged targets before replacing.
- tmux vs systemd socket management abstraction.
- port conflict assertions.

From mkaito:

- Per-instance users/directories.
- Honest separation between service management and modpack installation.
- Optional rsync operator workflow.

From aster-void:

- Version-locked `upstreamDir` source model.
- Simple copy/symlink sync script.

From endernix:

- Isolated client instance mindset.
- Modrinth lockfile/update workflow.

## Recommended future research directions

If continuing research, investigate:

1. GTNH Daily artifact retention and GitHub Actions API behavior.
2. `gtnh-daily-updater` internals and CLI stability.
3. Packwiz and whether it can model any part of GTNH Daily extras/configs.
4. Existing Nix modules for Prism Launcher or MultiMC instance management.
5. Backup strategies for large mutable Minecraft worlds on NixOS.
6. Whether `nix-minecraft` can be extended cleanly with a custom GTNH server package/module.
7. Whether a Docker-based GTNH release workflow and a NixOS-native Daily workflow should be separate modules.

## Repository naming context

The chosen name is:

```text
nix-horizons
```

Other names considered included:

- `gtnh-daily-server-flake`
- `gtnh-daily-nix`
- `gtnh-daily-flake`
- `new-nix-horizons`
- `horizon-sync`
- `declarative-horizons`
- `prism-horizons`
- `horizons-as-code`

The user liked `nix-horizons`.
