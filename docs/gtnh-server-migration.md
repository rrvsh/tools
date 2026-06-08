# GTNH 2.8.4 Prism-to-NixOS server migration plan

This document captures an end-to-end implementation plan for migrating a local Prism Launcher GT New Horizons `2.8.4` singleplayer instance to a native NixOS `systemd` server on `nemesis`.

Primary references:

- GTNH Server Setup: <https://wiki.gtnewhorizons.com/wiki/Server_Setup>
- GTNH Installing and Migrating: <https://wiki.gtnewhorizons.com/wiki/Installing_and_Migrating>
- GTNH Linux/Oracle setup guide, Java 25 notes and systemd/tmux examples: <https://wiki.gtnewhorizons.com/wiki/Server_Setup_(Linux,_Oracle_Cloud)>
- itzg/docker-minecraft-server GTNH docs, useful for GTNH-specific defaults and Java args: <https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/mod-platforms/gtnh/>
- NixOS Minecraft Server wiki, useful for NixOS service behavior/console/FIFO pattern: <https://wiki.nixos.org/wiki/Minecraft_Server>
- NixOS upstream module implementation for `services.minecraft-server`: `nixos/modules/services/games/minecraft-server.nix` in nixpkgs.

## Design choice

Use a native custom NixOS module instead of the stock `services.minecraft-server` module.

Why:

- GTNH `2.8.4` Java 17+ server starts with `@java9args.txt -jar lwjgl3ify-forgePatches.jar nogui`, not a normal vanilla server jar.
- The stock NixOS module is excellent for vanilla-style packages exposing `/bin/minecraft-server`, but GTNH is easier and clearer as a dedicated service.
- We still borrow the NixOS module's useful FIFO console pattern so commands can be sent with `echo "say hi" > /run/gtnh-server.stdin`.

GTNH-specific constraints from the GTNH docs:

- Server and client GTNH versions must match exactly.
- Use the official GTNH server pack, not a Prism client instance, as the server base.
- For GTNH `2.8+`, Java 25 is supported/recommended.
- The official server pack for this migration is:

```text
https://downloads.gtnewhorizons.com/ServerPacks/GT_New_Horizons_2.8.4_Server_Java_17-25.zip
```

## 1. Add the GTNH server NixOS module

Create `nix/modules/gtnh-server.nix`:

```nix
{
  # Standard NixOS module arguments.
  # `pkgs` gives access to Java and shell utilities.
  # `lib` is included for future option work even if this first version is mostly static.
  config,
  lib,
  pkgs,
  ...
}:
let
  # Persistent state directory for the GTNH server.
  # This holds the unpacked official server pack, configs, world, logs, backups, etc.
  # It is intentionally outside the Nix store because Minecraft server state is mutable.
  gtnhDir = "/srv/gtnh";

  # GTNH 2.8+ supports Java 17-25; GTNH docs currently recommend Java 25 for 2.8+.
  # Source: GTNH Installing and Migrating + Linux/Oracle server setup guide.
  java = pkgs.jdk25_headless;

  # Graceful shutdown helper.
  # We send `stop` to the server console FIFO first, mirroring the console/FIFO approach
  # used by NixOS's stock minecraft-server module. If the process does not exit in time,
  # systemd can still terminate it.
  stopScript = pkgs.writeShellScript "gtnh-stop" ''
    set -euo pipefail

    # Ask Minecraft/Forge to save and stop cleanly.
    if [ -p /run/gtnh-server.stdin ]; then
      echo "stop" > /run/gtnh-server.stdin
    fi

    # Wait up to 120 seconds because GTNH can take a while to save large worlds.
    timeout=120
    while kill -0 "$1" 2>/dev/null && [ "$timeout" -gt 0 ]; do
      sleep 1
      timeout=$((timeout - 1))
    done

    # If the JVM is still alive after the graceful timeout, ask it to terminate.
    if kill -0 "$1" 2>/dev/null; then
      kill -TERM "$1"
    fi
  '';
in
{
  config.flake.modules.nixos.gtnh-server = {
    # Dedicated unprivileged service account.
    # Minecraft does not need to run as a login user or as root.
    users.users.gtnh = {
      description = "GT New Horizons server user";
      isSystemUser = true;
      group = "gtnh";
      home = gtnhDir;
      createHome = true;
    };

    users.groups.gtnh = { };

    # Ensure /srv/gtnh exists with the correct owner and restrictive permissions.
    # The actual server pack and world are installed/copied there outside the Nix store.
    systemd.tmpfiles.rules = [
      "d ${gtnhDir} 0750 gtnh gtnh -"
    ];

    # Open default Minecraft Java Edition port.
    # GTNH docs and Minecraft defaults use 25565.
    # TCP is gameplay; UDP is commonly opened for pings/query compatibility.
    networking.firewall.allowedTCPPorts = [ 25565 ];
    networking.firewall.allowedUDPPorts = [ 25565 ];

    # FIFO socket for server console input.
    # This gives a simple admin path:
    #   echo "say hello" | sudo tee /run/gtnh-server.stdin
    # Pattern reference: NixOS `services.minecraft-server` module and wiki.
    systemd.sockets.gtnh-server = {
      bindsTo = [ "gtnh-server.service" ];
      socketConfig = {
        ListenFIFO = "/run/gtnh-server.stdin";
        SocketMode = "0660";
        SocketUser = "gtnh";
        SocketGroup = "gtnh";
        RemoveOnStop = true;
        FlushPending = true;
      };
    };

    systemd.services.gtnh-server = {
      description = "GT New Horizons 2.8.4 Server";
      wantedBy = [ "multi-user.target" ];
      requires = [ "gtnh-server.socket" ];
      after = [
        "network-online.target"
        "gtnh-server.socket"
      ];
      wants = [ "network-online.target" ];

      # Put Java and basic shell utilities in PATH for any scripts or diagnostics.
      path = [
        java
        pkgs.coreutils
        pkgs.bash
      ];

      serviceConfig = {
        User = "gtnh";
        Group = "gtnh";
        WorkingDirectory = gtnhDir;

        # Restart on JVM crashes, but not after a clean `stop`.
        Restart = "on-failure";
        RestartSec = "30s";
        SuccessExitStatus = "0 143";

        # Connect systemd's FIFO socket to stdin so console commands can be sent.
        StandardInput = "socket";
        StandardOutput = "journal";
        StandardError = "journal";

        # GTNH Java 17+ startup form.
        # Sources:
        # - GTNH Java 17+ server pack startserver-java9.sh
        # - GTNH Linux/Oracle guide suggests Java 25 + ZGC
        # - itzg GTNH docs list: -Dfml.readTimeout=180 @java9args.txt -jar lwjgl3ify-forgePatches.jar
        ExecStart = ''
          ${java}/bin/java \
            -Xms6G \
            -Xmx10G \
            -XX:+UseZGC \
            -Dfml.readTimeout=180 \
            @java9args.txt \
            -jar lwjgl3ify-forgePatches.jar \
            nogui
        '';

        # Use the graceful stop script above.
        ExecStop = "${stopScript} $MAINPID";

        # Basic hardening. Keep it moderate because modded Minecraft writes many files
        # under its working directory and may behave poorly with very strict sandboxing.
        UMask = "0027";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ gtnhDir ];
        ProtectHome = true;
      };
    };
  };
}
```

## 2. Import the server module on `nemesis`

Edit `nix/hosts.nix` and add `cfg.modules.nixos.gtnh-server` to `nemesis.modules`:

```nix
modules = [
  cfg.modules.nixos.user-primary
  cfg.modules.nixos.nvidia-graphics
  cfg.modules.nixos.steam
  cfg.modules.nixos.prismlauncher
  cfg.modules.nixos.daily-midnight-poweroff

  # Enables the native GTNH 2.8.4 systemd service on nemesis.
  # Defined in nix/modules/gtnh-server.nix.
  cfg.modules.nixos.gtnh-server

  (
    {
      config,
      pkgs,
      lib,
      modulesPath,
      ...
    }:
    {
      # Existing nemesis hardware/filesystem/boot config remains here.
    }
  )
];
```

## 3. Check and rebuild NixOS

Run from the repo on `nemesis`:

```sh
# Track the new module before evaluation. New Nix files must be git-tracked
# for flake evaluation in this repo workflow.
git add nix/modules/gtnh-server.nix nix/hosts.nix

# Format only Nix files using the repo's just recipe.
nix develop -c just format-nix

# Validate Nix configuration.
nix develop -c just check-nix

# Inspect generated changes before rebuild.
git diff

# Rebuild the current host. Repo policy: only do this after explicit approval.
nix develop -c just rb
```

## 4. Install official GTNH server files

The service will not start successfully until the official server pack has been unpacked into `/srv/gtnh`.

```sh
# Stop the service in case systemd attempted to start it before files existed.
sudo systemctl stop gtnh-server.service

# Download the official GTNH 2.8.4 Java 17-25 server pack.
# Source: GTNH downloads/server setup docs.
cd /tmp
curl -LO https://downloads.gtnewhorizons.com/ServerPacks/GT_New_Horizons_2.8.4_Server_Java_17-25.zip

# Ensure target state directory exists.
sudo mkdir -p /srv/gtnh

# Unpack into /srv/gtnh. Use bsdtar if present.
sudo bsdtar -xf GT_New_Horizons_2.8.4_Server_Java_17-25.zip -C /srv/gtnh

# If bsdtar is unavailable, use comma to run unzip without permanently installing it:
# , unzip GT_New_Horizons_2.8.4_Server_Java_17-25.zip -d /tmp/gtnh-unpack
# sudo rsync -a /tmp/gtnh-unpack/ /srv/gtnh/

# Accept Mojang's EULA. Required by both GTNH/NixOS docs and Minecraft itself.
echo "eula=true" | sudo tee /srv/gtnh/eula.txt

# Make all server files owned by the service account.
sudo chown -R gtnh:gtnh /srv/gtnh
sudo chmod -R u+rwX,g+rX,o-rwx /srv/gtnh

# Sanity-check that Java 17+ GTNH startup files are present.
ls -la /srv/gtnh/lwjgl3ify-forgePatches.jar /srv/gtnh/java9args.txt
```

## 5. Configure `server.properties`

Edit `/srv/gtnh/server.properties`:

```sh
sudoedit /srv/gtnh/server.properties
```

Recommended baseline:

```properties
# World folder name under /srv/gtnh.
# The migration below copies the Prism world into /srv/gtnh/world.
level-name=world

# GTNH intended world generation.
# Sources: GTNH Server Setup FAQ and itzg GTNH defaults.
level-type=rwg

# GTNH default/recommended difficulty.
difficulty=hard

# Required/recommended for modded movement and GTNH server defaults.
allow-flight=true

# GTNH/itzg default. Keep enabled unless there is a reason not to.
enable-command-block=true

# Private local server safety. Add players with `whitelist add USERNAME`.
white-list=true

# Keep small for a local/private server.
max-players=5

# Default Minecraft port; firewall module opens this.
server-port=25565

# Server list display text.
motd=GT New Horizons 2.8.4 on nemesis
```

Then fix ownership if needed:

```sh
sudo chown gtnh:gtnh /srv/gtnh/server.properties
```

## 6. First boot test with a generated empty world

Do this before copying the Prism world. It proves the server pack, Java, service, firewall, and console FIFO work.

```sh
# Start GTNH. First launch can take several minutes.
sudo systemctl start gtnh-server.service

# Follow logs. Wait until startup completes.
journalctl -fu gtnh-server.service

# In another terminal, test console input through the FIFO.
echo "say GTNH server online" | sudo tee /run/gtnh-server.stdin

# Stop cleanly before migration.
echo "stop" | sudo tee /run/gtnh-server.stdin

# Confirm stopped or stopping cleanly.
systemctl status gtnh-server.service
```

## 7. Locate and back up the Prism singleplayer world

NOTE: backups must include other folders than **/saves. check the gtnh wiki and local instance backup configuration.

Prism instances are usually under `~/.local/share/PrismLauncher/instances` on Linux.

```sh
# Find Prism saves directories.
find ~/.local/share/PrismLauncher/instances -maxdepth 3 -type d -name saves
```

Typical world path:

```text
~/.local/share/PrismLauncher/instances/<INSTANCE>/.minecraft/saves/<WORLD>
```

Backup the world before touching it:

```sh
# Replace <INSTANCE> and <WORLD>.
mkdir -p ~/gtnh-migration-backups

tar -C ~/.local/share/PrismLauncher/instances/<INSTANCE>/.minecraft/saves \
  -czf ~/gtnh-migration-backups/<WORLD>-before-server-migration.tar.gz \
  <WORLD>
```

## 8. Copy the Prism world to the server

```sh
# Server must be stopped before replacing the world.
sudo systemctl stop gtnh-server.service

# Move the generated test world aside instead of deleting it.
sudo mv /srv/gtnh/world /srv/gtnh/world.empty-test.$(date +%Y%m%d-%H%M%S)

# Copy the Prism singleplayer save as the server's `world` directory.
# The trailing slashes are intentional: copy contents of <WORLD> into /srv/gtnh/world.
sudo rsync -a --info=progress2 \
  ~/.local/share/PrismLauncher/instances/<INSTANCE>/.minecraft/saves/<WORLD>/ \
  /srv/gtnh/world/

# Give ownership to the service account.
sudo chown -R gtnh:gtnh /srv/gtnh/world

# Start the migrated world.
sudo systemctl start gtnh-server.service
journalctl -fu gtnh-server.service
```

## 9. Whitelist and op yourself

Run after the server is up:

```sh
# Replace YOUR_USERNAME with the exact Minecraft username.
# Whitelist is recommended for private/self-hosted servers.
echo "whitelist add YOUR_USERNAME" | sudo tee /run/gtnh-server.stdin

# Give yourself admin permissions for migration validation and future admin tasks.
echo "op YOUR_USERNAME" | sudo tee /run/gtnh-server.stdin

# Force a save after changing admin files.
echo "save-all" | sudo tee /run/gtnh-server.stdin
```

Connect from Prism:

```text
nemesis:25565
```

or use the LAN IP of `nemesis`.

## 10. Validate the migrated world

Verify before deleting any backups:

- Spawn location is expected.
- Inventory and armor are correct.
- Quest book progress is intact.
- Machines/multiblocks are present and valid.
- Dimensions are present.
- Claimed/chunk-loaded areas behave as expected.
- Server TPS is acceptable after initial chunk loading.

Caveat:

- Singleplayer-to-server migrations can sometimes expose Minecraft `level.dat` player data vs UUID-based `playerdata` differences. If inventory or position is wrong, stop the server and keep the original save backup. Fixing is possible with NBT tooling, but should be done carefully.

## 11. Optional: add system-level GTNH backups

GTNH's ServerUtilities includes backups, but an external host-level backup is still useful.

Create `nix/modules/gtnh-backups.nix`:

```nix
{ pkgs, ... }:

let
  # Backup destination outside the live server directory.
  backupDir = "/srv/gtnh-backups";
in
{
  config.flake.modules.nixos.gtnh-backups = {
    # Ensure backup directory exists. Owned by root because backups are written by systemd.
    systemd.tmpfiles.rules = [
      "d ${backupDir} 0750 root root -"
    ];

    systemd.services.gtnh-backup = {
      description = "Backup GTNH server";
      serviceConfig = {
        Type = "oneshot";

        ExecStart = pkgs.writeShellScript "gtnh-backup" ''
          set -euo pipefail

          ts="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
          dest="${backupDir}/gtnh-$ts.tar.zst"

          # Ask the server to flush world data before taking a filesystem backup.
          # This is not as strong as a fully quiesced backup, but is simple and low disruption.
          echo "say Starting server backup" > /run/gtnh-server.stdin || true
          echo "save-all" > /run/gtnh-server.stdin || true
          sleep 10

          # Archive /srv/gtnh as mutable state.
          # Exclude GTNH's own backup folder to avoid recursive backup bloat.
          ${pkgs.gnutar}/bin/tar \
            --exclude='/srv/gtnh/backups' \
            -C /srv \
            -I '${pkgs.zstd}/bin/zstd -T0 -10' \
            -cf "$dest" \
            gtnh

          # Keep 14 days of host-level backups.
          ${pkgs.findutils}/bin/find ${backupDir} \
            -name 'gtnh-*.tar.zst' \
            -type f \
            -mtime +14 \
            -delete

          echo "say Server backup complete" > /run/gtnh-server.stdin || true
        '';
      };
    };

    systemd.timers.gtnh-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # Run daily at 03:30 local time.
        OnCalendar = "03:30";

        # If the machine was off at 03:30, run once after boot.
        Persistent = true;
      };
    };
  };
}
```

Import it in `nemesis.modules`:

```nix
modules = [
  # Existing nemesis modules...
  cfg.modules.nixos.gtnh-server

  # Adds a daily compressed /srv/gtnh backup timer.
  cfg.modules.nixos.gtnh-backups
];
```

Apply:

```sh
git add nix/modules/gtnh-backups.nix nix/hosts.nix
nix develop -c just format-nix
nix develop -c just check-nix
nix develop -c just rb
```

Manual backup test:

```sh
sudo systemctl start gtnh-backup.service
ls -lh /srv/gtnh-backups
```

## 12. Admin command reference

```sh
# Follow logs.
journalctl -fu gtnh-server.service

# Service lifecycle.
sudo systemctl start gtnh-server.service
sudo systemctl stop gtnh-server.service
sudo systemctl restart gtnh-server.service
sudo systemctl status gtnh-server.service

# Send Minecraft console commands through the FIFO.
echo "say hello" | sudo tee /run/gtnh-server.stdin
echo "list" | sudo tee /run/gtnh-server.stdin
echo "save-all" | sudo tee /run/gtnh-server.stdin
echo "stop" | sudo tee /run/gtnh-server.stdin

# Check listener.
ss -ltnup | grep 25565

# Check backup timer.
systemctl list-timers | grep gtnh
```

## 13. Commit

```sh
git status
git add nix/modules/gtnh-server.nix nix/modules/gtnh-backups.nix nix/hosts.nix docs/gtnh-server-migration.md
git commit -m "feat(gtnh-server): document nemesis GTNH migration"
```
