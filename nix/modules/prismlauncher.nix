{ config, inputs, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.prismlauncher ];
  };
in
{
  config.flake.modules = {
    darwin.prismlauncher = osModule;
    nixos.prismlauncher = osModule;
    homeManager.prismlauncher =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        gtnhDailyInstanceName = "GT New Horizons (Daily)";
        gtnhDailyInstanceDir = "${config.home.homeDirectory}/.local/share/PrismLauncher/instances/${gtnhDailyInstanceName}";
        gtnhDailyUpdater = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gtnh-daily-updater;
        gtnhDailyClientSync = pkgs.writeShellScriptBin "gtnh-daily-client-sync" ''
          set -euo pipefail

          server="''${GTNH_DAILY_SERVER:-nemesis}"
          remote_manifest="/var/lib/gtnh-daily/current-manifest.json"
          remote_hash="/var/lib/gtnh-daily/current-manifest.sha256"
          instance_dir="${gtnhDailyInstanceDir}"
          state_file="$instance_dir/.gtnh-daily-updater.json"
          cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/gtnh-daily-client-sync"
          backup_dir="$HOME/.local/share/PrismLauncher/backups"
          local_manifest="$cache_dir/current-manifest.json"
          local_hash="$cache_dir/current-manifest.sha256"
          lock_file="$cache_dir/sync.lock"

          mkdir -p "$cache_dir"
          exec 9>"$lock_file"
          ${pkgs.util-linux}/bin/flock -n 9

          if [ ! -d "$instance_dir" ]; then
            echo "Missing Prism instance: $instance_dir" >&2
            exit 1
          fi
          if [ ! -f "$state_file" ]; then
            echo "Missing updater state: $state_file" >&2
            echo "Initialize once with:" >&2
            echo "  gtnh-daily-updater init --instance-dir '$instance_dir' --side client --config <server-config-version>" >&2
            exit 1
          fi
          if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f 'prismlauncher|net\.minecraft|minecraft|lwjgl3ify' >/dev/null; then
            echo "Prism or Minecraft appears to be running; refusing to update the client instance." >&2
            exit 1
          fi

          fetched_hash="$(${pkgs.openssh}/bin/ssh -o BatchMode=yes "$server" "cat '$remote_hash'")"
          if [ -f "$local_hash" ] && [ "$fetched_hash" = "$(cat "$local_hash")" ]; then
            echo "GTNH Daily client is already synced to $server."
            exit 0
          fi

          ${pkgs.openssh}/bin/scp -q -o BatchMode=yes "$server:$remote_manifest" "$local_manifest"
          expected_hash="$(printf '%s\n' "$fetched_hash" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
          actual_hash="$(${pkgs.coreutils}/bin/sha256sum "$local_manifest" | ${pkgs.gawk}/bin/awk '{ print $1 }')"
          if [ "$expected_hash" != "$actual_hash" ]; then
            echo "Manifest hash mismatch: expected $expected_hash, got $actual_hash" >&2
            exit 1
          fi

          mkdir -p "$backup_dir"
          backup="$backup_dir/gtnh-daily-client-$(${pkgs.coreutils}/bin/date -u +%Y%m%d-%H%M%S).tar.zst"
          ${pkgs.gnutar}/bin/tar --use-compress-program=${pkgs.zstd}/bin/zstd -C "$HOME/.local/share/PrismLauncher/instances" -cf "$backup" "${gtnhDailyInstanceName}"

          PATH=${pkgs.git}/bin:$PATH ${gtnhDailyUpdater}/bin/gtnh-daily-updater update \
            --instance-dir "$instance_dir" \
            --manifest-file "$local_manifest"
          printf '%s\n' "$fetched_hash" > "$local_hash"
          echo "Synced GTNH Daily client to $server manifest $expected_hash"
        '';
      in
      {
        xdg.desktopEntries = {
          gtnh = {
            name = "GregTech New Horizons";
            icon = "${config.home.homeDirectory}/.local/share/PrismLauncher/instances/GT_New_Horizons_2.8.4_Java_17-25/icon.png";
            exec = "prismlauncher --launch GT_New_Horizons_2.8.4_Java_17-25";
          };
          gtnh-daily = {
            name = gtnhDailyInstanceName;
            icon = "${gtnhDailyInstanceDir}/icon.png";
            exec = "prismlauncher --launch \"${gtnhDailyInstanceName}\"";
          };
        };
        home.packages = [
          (pkgs.prismlauncher.override {
            jdks = [ pkgs.jdk25 ];
          })
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ gtnhDailyClientSync ];
        systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          services.gtnh-daily-client-sync = {
            Unit = {
              Description = "Sync GTNH Daily Prism client to the server manifest";
              After = [ "network-online.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${gtnhDailyClientSync}/bin/gtnh-daily-client-sync";
            };
          };
          timers.gtnh-daily-client-sync = {
            Unit.Description = "Sync GTNH Daily Prism client on schedule";
            Timer = {
              OnCalendar = "hourly";
              Persistent = true;
              RandomizedDelaySec = "15m";
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };
      };
  };
}
