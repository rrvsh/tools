# Research note: Minecraft server management options

Date: 2026-06-15

Scope: itzg `docker-minecraft-server` for GTNH, modded Minecraft server flakes/modules, and the nixpkgs `services.minecraft-server` NixOS module. This note is research only; it does not change the current GTNH Daily implementation.

## Executive summary

For this repo's **GTNH Daily** goal, the current custom NixOS module remains justified.

- `itzg/docker-minecraft-server` is the strongest off-the-shelf **container** option for GTNH stable/beta releases. It has first-class `TYPE=GTNH`, Java 25 guidance, GTNH-specific defaults, and an update/install path. It is less aligned with our Daily manifest-pinning/client-sync design because it targets GTNH download releases via `versions.json`, not the `gtnh-daily-updater` manifest-file workflow.
- nixpkgs `services.minecraft-server` is a solid simple single-server module: EULA, one service, FIFO stdin, hardening, declarative `server.properties`/whitelist, and firewall. It does not solve modpack bootstrap/update, multiple instances, GTNH launch details, Daily artifact discovery, or client/server manifest pinning.
- `Infinidoge/nix-minecraft` is the most mature Nix flake ecosystem option for multiple Minecraft servers. It has multiple server instances, Fabric/Quilt/Paper/Purpur/NeoForge packages, Packwiz/Modrinth helpers, symlinks/files management, tmux or systemd-socket management, hardening, and generated service units. It still does not directly package old Forge 1.7.10 GTNH Daily or `gtnh-daily-updater` semantics.
- Other flakes (`mkaito/nixos-modded-minecraft-servers`, `aster-void/nix-mc`, `TLATER/nix-minecraft-servers`, `jyooru/nix-minecraft-servers`, `Ninlives/minecraft.nix`, `endernix`) are useful design references, but either intentionally punt on modpack installation, are simpler/younger, are deprecated, or are more client/Fabric-focused.

Best extraction ideas for our module:

1. Keep the **systemd FIFO stdin pattern** from nixpkgs/Infinidoge; we already use it.
2. Consider adopting a multi-server-style `symlinks`/`files` abstraction only if we later generalize beyond GTNH Daily.
3. Consider a small `environmentFile`/credential option for `GITHUB_TOKEN`, inspired by Infinidoge's environment-file support.
4. Keep GTNH-specific bootstrap/update/client-sync custom because no researched module covers the full Daily manifest-pinning boundary.

## itzg/docker-minecraft-server for GTNH

### What it provides

The upstream docs say GTNH has its own `TYPE` because the pack has special deployment/update needs. Configuration defaults include `GTNH_PACK_VERSION=latest`, `GTNH_DELETE_BACKUPS=false`, and `SKIP_GTNH_UPDATE_CHECK=false` ([docs](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/docs/types-and-platforms/mod-platforms/gtnh.md#L1-L11)). Version selection supports `latest`, `latest-dev`, or a specific version, with the docs recommending a specific version for manual update control ([docs](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/docs/types-and-platforms/mod-platforms/gtnh.md#L13-L17)).

The official GTNH wiki's container page says `TYPE: GTNH` support was added in `docker-minecraft-server` 2025.12.0 and is the recommended Docker path for most users. Its compose example uses `image: itzg/minecraft-server:java25`, `EULA: TRUE`, `TYPE: GTNH`, and `GTNH_PACK_VERSION: 2.8.1` (GTNH wiki content fetched from `Server_Setup_(Container)`). The repo example matches that shape ([compose example](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/examples/gtnh/docker-compose-type-gtnh.yaml#L1-L24)).

GTNH resource guidance in the itzg docs is close to our current sizing: 2-4 CPU cores, 6 GiB RAM plus player/tier overhead, and 20+ GiB storage, SSD preferred ([docs](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/docs/types-and-platforms/mod-platforms/gtnh.md#L19-L28)). The docs recommend Java 17+ and Java 25 for GTNH 2.8.0+ ([docs](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/docs/types-and-platforms/mod-platforms/gtnh.md#L30-L34)).

### How GTNH deployment works internally

`start-configuration` dispatches `TYPE=GTNH` to `start-deployGTNH` ([dispatch](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-configuration#L222-L246)). The GTNH script selects a download from `https://downloads.gtnewhorizons.com/versions.json`: `latest-dev` chooses the latest beta/RC, `latest` chooses the latest stable, and a specific `GTNH_PACK_VERSION` selects that exact version key ([selection](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-deployGTNH#L7-L40)). It then selects Java 8 or Java 17+ server URLs based on the container Java version and the release's max Java version ([Java URL choice](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-deployGTNH#L42-L60)).

On update, it deletes/replaces `libraries`, `mods`, `resources`, `scripts`, launch jars/scripts, and backs up `config` into `/data/gtnh-upgrade-<timestamp>` before copying the new config tree. It restores `config/JourneyMapServer` from the backup if present ([update function](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-deployGTNH#L73-L150)). The install/update decision is keyed by `/data/.gtnh-version` matching the selected download basename ([install/update gate](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-deployGTNH#L163-L224)).

The script sets GTNH server defaults before normal setup: `ALLOW_FLIGHT=true`, `LEVEL_TYPE=rwg`, `DIFFICULTY=3`, `ENABLE_COMMAND_BLOCK=true`, and a GTNH MOTD ([defaults](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-deployGTNH#L228-L235)). For Java 17+, it sets `SERVER=/data/lwjgl3ify-forgePatches.jar`, `VERSION=1.7.10`, and `USES_MODS=true` ([server selection](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-deployGTNH#L239-L259)). Final Java args add `-Dfml.readTimeout=180` and, for Java 17+, `@java9args.txt` ([final args](https://github.com/itzg/docker-minecraft-server/blob/1a8844cb625d753409f02f3cfbd46eefd5c5d939/scripts/start-finalExec#L409-L423)).

### Strengths

- Very practical for container users: one image, one volume, environment variables.
- Maintained broad Minecraft server image with GTNH-specific support.
- Encodes GTNH defaults and Java-version selection.
- Handles stable/beta GTNH server pack installs/updates automatically.
- Container boundary is convenient for running multiple unrelated servers on non-NixOS hosts.

### Limitations for our Daily setup

- It targets GTNH release downloads via `downloads.gtnewhorizons.com/versions.json`, not GitHub Actions Daily artifacts plus `gtnh-daily-updater` manifests.
- Its update marker is `.gtnh-version` based on the server zip basename, not the exact server-applied Daily manifest hash.
- It does not publish a pinned manifest for clients or coordinate a Prism client sync.
- Its update strategy replaces config directories and preserves only selected state such as `JourneyMapServer`; our current updater-based flow uses `gtnh-daily-updater` config merging and declared extras/excludes.
- Docker adds another runtime/orchestration layer on NixOS. That may be worthwhile for portability, but it is less idiomatic if the host is already fully NixOS-managed.

## nixpkgs `services.minecraft-server`

The local nixpkgs checkout used for this review is `/home/rafiq/1_repos/nixpkgs` at commit `b5e9cca1667666e70abf6814c62dc0b1c759d7b1`.

### What it provides

The module exposes a single `services.minecraft-server` service. Options include `enable`, `declarative`, `eula`, `dataDir`, `openFirewall`, `whitelist`, `serverProperties`, `package`, and `jvmOpts` ([options](https://github.com/NixOS/nixpkgs/blob/b5e9cca1667666e70abf6814c62dc0b1c759d7b1/nixos/modules/services/games/minecraft-server.nix#L67-L190)). It creates a system `minecraft` user/group and a FIFO socket at `/run/minecraft-server.stdin` for console input ([user/socket](https://github.com/NixOS/nixpkgs/blob/b5e9cca1667666e70abf6814c62dc0b1c759d7b1/nixos/modules/services/games/minecraft-server.nix#L193-L214)).

The systemd service runs `${cfg.package}/bin/minecraft-server ${cfg.jvmOpts}`, uses the FIFO as standard input, logs to journald, and includes substantial hardening such as `PrivateTmp`, `PrivateUsers`, `ProtectHome`, `ProtectProc`, namespace restrictions, and `UMask=0077` ([service/hardening](https://github.com/NixOS/nixpkgs/blob/b5e9cca1667666e70abf6814c62dc0b1c759d7b1/nixos/modules/services/games/minecraft-server.nix#L216-L260)).

Pre-start always symlinks a Nix-managed `eula.txt`; in declarative mode it writes/symlinks `whitelist.json` and `server.properties`, backing up stateful originals the first time it becomes declarative ([preStart](https://github.com/NixOS/nixpkgs/blob/b5e9cca1667666e70abf6814c62dc0b1c759d7b1/nixos/modules/services/games/minecraft-server.nix#L262-L295)). Firewall opening uses declared ports when `declarative=true`, including RCON/query where enabled; otherwise it opens the default 25565 ([firewall](https://github.com/NixOS/nixpkgs/blob/b5e9cca1667666e70abf6814c62dc0b1c759d7b1/nixos/modules/services/games/minecraft-server.nix#L298-L313)). The module asserts `eula=true` before running ([assertion](https://github.com/NixOS/nixpkgs/blob/b5e9cca1667666e70abf6814c62dc0b1c759d7b1/nixos/modules/services/games/minecraft-server.nix#L315-L323)).

### Strengths

- Minimal, upstream NixOS-native, and well hardened.
- Good pattern for EULA, FIFO stdin, service user, journald, and declarative `server.properties`.
- Perfect for vanilla or a prepackaged server derivation that already knows how to launch as `bin/minecraft-server`.

### Limitations for GTNH Daily

- Single server only; no multi-instance attrset.
- No modpack bootstrap/update logic.
- No Forge/GTNH artifact discovery.
- No client sync or server-published manifest flow.
- `ExecStart` assumes package shape `${package}/bin/minecraft-server`; GTNH's Java 17+ launch path is `java ... @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui` inside a mutable server directory.
- Declarative mode owns `server.properties`/whitelist but not GTNH config merging, extras/excludes, or updater state.

Useful takeaway: our module intentionally mirrors the strong parts—system user, FIFO stdin, journald, hardening, EULA assertion/management, firewall—from nixpkgs, but needs custom GTNH Daily bootstrap/update/client pinning.

## Modded Minecraft server flakes/modules

### Infinidoge/nix-minecraft

This is the strongest Nix ecosystem option found. It focuses on server-side Minecraft and packages Vanilla, Fabric, Legacy Fabric, Quilt, Paper, Purpur, NeoForge, Velocity, and tools including `nix-modrinth-prefetch`, `fetchPackwizModpack`, and `fetchModrinthModpack` ([README](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/README.md#L3-L22)). It is flake-first and installed by importing `nixosModules.minecraft-servers` plus the overlay ([install](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/README.md#L34-L56)).

It supports multiple named servers under `services.minecraft-servers.servers`, with per-server enable/autostart/firewall/restart/reload hooks/stop command/whitelist/operators/bans/serverProperties/package/jvmOpts/path/environment/symlinks/files/management options ([server options](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/modules/minecraft-servers.nix#L307-L560)). It supports both tmux management and systemd FIFO socket management; the systemd socket mode uses `StandardInput=socket`, journald output, and writes the stop command to the FIFO ([management system](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/modules/minecraft-servers.nix#L80-L180)).

It has a granular file model: `symlinks` for read-only declarative paths and `files` for copied writable paths, including generated JSON/properties/text formats and optional environment-file substitution for secrets ([file/env options](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/modules/minecraft-servers.nix#L260-L299), [file options](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/modules/minecraft-servers.nix#L560-L617)). At start, it cleans files it previously managed, backs up pre-existing unmanaged targets, creates symlinks/copies, and marks managed files in `.nix-minecraft-managed` ([start-pre](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/modules/minecraft-servers.nix#L720-L854)). It also opens per-server firewall ports and asserts no duplicate open server ports ([firewall/assertions](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/modules/minecraft-servers.nix#L680-L717)).

The service hardening is similar to nixpkgs and includes `PrivateTmp`, `PrivateUsers`, `ProtectHome`, kernel protections, address-family restrictions, and `UMask=0007` ([service hardening](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/modules/minecraft-servers.nix#L940-L1010)).

Packwiz integration is documented: a fetched Packwiz modpack can symlink `mods` and copy selected config files, with a warning to use stable URLs/tags/commits for reproducibility ([Packwiz docs](https://github.com/Infinidoge/nix-minecraft/blob/e6f8bec35104ca5955efe73742da58d2823684f7/README.md#L157-L180)).

Relevance to GTNH Daily:

- Great architectural reference for multi-server abstractions, file/symlink policy, environment-file secrets, and service management.
- Not currently a direct replacement for GTNH Daily because it does not provide Forge 1.7.10/GTNH Daily artifact/updater integration.
- Could be overkill unless we want to generalize our `gtnh-daily-server.nix` into a broader Minecraft server framework.

### mkaito/nixos-modded-minecraft-servers

This flake explicitly supports multiple modded instances but deliberately avoids modpack installation. Its README says the module provides `services.modded-minecraft-servers`, with each instance using its name for the state folder and user (`/var/lib/mc-e2es`, user `mc-e2es`) and optional rsync SSH access ([README usage](https://github.com/mkaito/nixos-modded-minecraft-servers/blob/68f2066499c035fd81c9dacfea2f512d6b0b62e5/README.md#L1-L39)). It states that `server.properties` is overwritten and that the module does not support stateful configuration for that file ([server config](https://github.com/mkaito/nixos-modded-minecraft-servers/blob/68f2066499c035fd81c9dacfea2f512d6b0b62e5/README.md#L43-L60)).

For modded packs, it says it makes no attempt to guess how to package or run a modpack; it provides a state folder where files are dumped and runs `start.sh` with `$JVMOPTS` set ([modded philosophy](https://github.com/mkaito/nixos-modded-minecraft-servers/blob/68f2066499c035fd81c9dacfea2f512d6b0b62e5/README.md#L72-L112)). The module implementation creates per-instance users/services, renders `server.properties`, symlinks EULA, and runs `/var/lib/${fullname}/start.sh` ([module service](https://github.com/mkaito/nixos-modded-minecraft-servers/blob/68f2066499c035fd81c9dacfea2f512d6b0b62e5/nixos/modules/services/games/minecraft-servers/default.nix#L141-L180)). It also asserts unique server/RCON/query ports and opens firewall ports ([assertions/firewall](https://github.com/mkaito/nixos-modded-minecraft-servers/blob/68f2066499c035fd81c9dacfea2f512d6b0b62e5/nixos/modules/services/games/minecraft-servers/default.nix#L110-L139), [firewall](https://github.com/mkaito/nixos-modded-minecraft-servers/blob/68f2066499c035fd81c9dacfea2f512d6b0b62e5/nixos/modules/services/games/minecraft-servers/default.nix#L201-L202)).

Relevance:

- Useful “minimal modded framework” reference.
- Philosophically opposite to our reproducibility goal: it expects the operator to install modpack files in the state directory.
- Not enough for GTNH Daily after wipe/rebuild without our separate bootstrap/updater layer.

### aster-void/nix-mc

`nix-mc` advertises Forge, NeoForge, and Bedrock support with systemd hardening, flexible file management, multi-server support, and automatic firewall ([README](https://github.com/aster-void/nix-mc/blob/458b4590d6b41f06a54397a819d7307fc7d63891/README.md#L1-L20)). It also explicitly recommends `Infinidoge/nix-minecraft` for most use cases, using `nix-mc` when a loader is unsupported by nix-minecraft or for Bedrock ([README note](https://github.com/aster-void/nix-mc/blob/458b4590d6b41f06a54397a819d7307fc7d63891/README.md#L1-L6)). Its usage model is version-locked server sources via flake inputs or `fetchFromGitHub`, with `upstreamDir`, `symlinks`, and `serverProperties` ([quick start](https://github.com/aster-void/nix-mc/blob/458b4590d6b41f06a54397a819d7307fc7d63891/README.md#L22-L58)). The README emphasizes version-locked sources as reproducible, atomic, rollback-friendly, and immutable-store-based ([version-locked benefits](https://github.com/aster-void/nix-mc/blob/458b4590d6b41f06a54397a819d7307fc7d63891/README.md#L140-L180)).

Implementation is simpler than Infinidoge: pre-start sync creates directories, copies declared writable files, symlinks declared paths, and optionally writes `server.properties` ([sync script](https://github.com/aster-void/nix-mc/blob/458b4590d6b41f06a54397a819d7307fc7d63891/nixosModules/nix-mc.nix#L1-L45)). Services run through tmux by default and include hardening such as `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome=true`, and `ReadWritePaths` for data/run dirs ([service](https://github.com/aster-void/nix-mc/blob/458b4590d6b41f06a54397a819d7307fc7d63891/nixosModules/nix-mc.nix#L72-L131)).

Relevance:

- Good design reference for a simple `upstreamDir` + `symlinks` + `files` model.
- If we ever pin a whole GTNH server artifact into the Nix store, this model becomes relevant.
- Less suited to Daily because Daily artifacts and updater state are mutable/runtime-discovered, and our world/config boundary is more nuanced.

### TLATER/nix-minecraft-servers

This repo is primarily a design/spec note rather than a complete implementation: it says almost none of the actual functionality is implemented ([README](https://github.com/TLATER/nix-minecraft-servers/blob/d7271c7db69a7195fd5399f779299580a5fbea48/README.md#L1-L8)). The interesting part is its analysis of Forge/modpacks: Forge installers download libraries and are impure; the proposed approach is to pre-account for those libraries and avoid automating the Forge installer download directly ([Forge analysis](https://github.com/TLATER/nix-minecraft-servers/blob/d7271c7db69a7195fd5399f779299580a5fbea48/README.md#L12-L43)). It also explains why CurseForge/modpack manifests and arbitrary “server files” packs are difficult to package purely: manifests may lack direct URLs, CurseForge access can be awkward, and server zips are arbitrary author-defined directories/scripts ([modpack analysis](https://github.com/TLATER/nix-minecraft-servers/blob/d7271c7db69a7195fd5399f779299580a5fbea48/README.md#L45-L138)).

Relevance:

- Strong conceptual justification for why GTNH Daily needs a pragmatic bootstrap/updater boundary instead of pretending every modpack artifact is a pure Nix derivation.
- Supports our choice to keep mutable updater/world state out of the Nix store while pinning/reconciling the parts that matter.

### jyooru/nix-minecraft-servers

This older flake packaged server versions and provided overlays/packages for use with `services.minecraft-server`, but the README now says it is no longer maintained and points to Infinidoge's `nix-minecraft` ([README](https://github.com/jyooru/nix-minecraft-servers/blob/48387fe72c74ad7b5bca624606f18d85e697022a/README.md#L1-L8)).

Relevance: historical only; prefer Infinidoge.

### Ninlives/minecraft.nix and iamanaws/endernix

`minecraft.nix` packages vanilla/fabric client and server derivations and supports `withConfig` for mods/resource packs/shader packs; for server, its table says `declarative` is currently a no-op ([README](https://github.com/Ninlives/minecraft.nix/blob/a0b850c5a1ca542026b594d14576bacddef6dfeb/README.md#L1-L27), [options](https://github.com/Ninlives/minecraft.nix/blob/a0b850c5a1ca542026b594d14576bacddef6dfeb/README.md#L77-L95)).

`endernix` builds on `minecraft.nix` for multiple isolated Minecraft installations, primarily client/installations rather than NixOS server services. It solves the shared-game-directory problem and can generate Modrinth lockfiles with URLs/hashes ([README](https://github.com/iamanaws/endernix/blob/05d1f2016f24660b2774ba907fff82824abbcb30/README.adoc#L1-L16), [lockfile flow](https://github.com/iamanaws/endernix/blob/05d1f2016f24660b2774ba907fff82824abbcb30/README.adoc#L17-L45), [mkInstance API](https://github.com/iamanaws/endernix/blob/05d1f2016f24660b2774ba907fff82824abbcb30/README.adoc#L160-L187)).

Relevance: useful for client-side/resource-pack thinking and Modrinth lockfile ideas, but not a GTNH server management replacement.

## Comparison against current GTNH Daily module

| Concern | itzg Docker GTNH | nixpkgs module | Infinidoge nix-minecraft | Current custom module |
| --- | --- | --- | --- | --- |
| GTNH-specific launch args | Yes | No | Not directly for GTNH 1.7.10 | Yes |
| Stable/RC GTNH server pack install | Yes | No | No direct GTNH support | Not target; Daily only |
| GTNH Daily GitHub Actions artifact bootstrap | No | No | No | Yes |
| `gtnh-daily-updater` integration | No | No | No | Yes |
| Server-published pinned manifest for clients | No | No | No | Yes |
| Prism client bootstrap/sync | No | No | No | Yes |
| Multiple server abstraction | Docker compose can do it | No | Yes | No, one GTNH Daily server |
| Declarative `server.properties` | Env/defaults | Yes | Yes | Only enforced port for now |
| Console management | Docker attach/RCON/pipe helpers | FIFO | tmux or FIFO | FIFO |
| Systemd hardening | Container isolation | Yes | Yes | Yes |
| World backup boundary | Volume responsibility | dataDir responsibility | dataDir responsibility | Explicitly documented |
| Pure Nix derivation for modpack | No | Only if package supplied | Some packwiz/Modrinth support | No; pragmatic runtime bootstrap |

## Practical recommendations

1. **Do not replace the current GTNH Daily module with nixpkgs `services.minecraft-server`.** It would remove most of the Daily-specific bootstrap/update/client-sync logic.
2. **Do not replace it with itzg Docker unless the goal changes to container portability or stable GTNH releases.** itzg is excellent for `TYPE=GTNH` release servers, but it does not address our exact Daily manifest pinning and Prism sync goals.
3. **Use Infinidoge as the main design reference if generalizing.** Its `services.minecraft-servers` module has the best patterns for multi-server definitions, file/symlink handling, environment-file secrets, port assertions, and management system selection.
4. **Keep our updater-first boundary.** TLATER's analysis reinforces that arbitrary Forge/modpack server files are hard to make purely reproducible. Our current compromise—bootstrap artifacts at runtime, then pin updater manifests and reconcile small declared policy—is appropriate.
5. **Potential follow-up improvements:**
   - add a documented `GITHUB_TOKEN` environment file/credential path for server bootstrap/update;
   - factor duplicated GitHub Actions artifact discovery between server and client;
   - optionally expose a small Nix option set for GTNH Daily ports, memory, update schedule, extras/excludes, and SSH server name if this module becomes reusable.
