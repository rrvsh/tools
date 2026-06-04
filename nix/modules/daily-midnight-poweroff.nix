{
  config.flake.modules.nixos.daily-midnight-poweroff =
    {
      config,
      pkgs,
      primaryUser,
      ...
    }:
    let
      uid = toString config.users.users.${primaryUser.name}.uid;
      runtimeDir = "/run/user/${uid}";
      idleStateFile = "${runtimeDir}/hypridle-state";
    in
    {
      home-manager.sharedModules = [
        (
          { pkgs, ... }:
          {
            services.hypridle.settings.listener = [
              {
                timeout = 60;
                on-timeout = "${pkgs.bash}/bin/bash -lc 'printf idle > \"${idleStateFile}\"'";
                on-resume = "${pkgs.bash}/bin/bash -lc 'printf active > \"${idleStateFile}\"'";
              }
            ];
          }
        )
      ];
      systemd.services.daily-midnight-poweroff = {
        description = "Power off daily at midnight";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "daily-midnight-poweroff" ''
            set -euo pipefail

            log() {
              printf '%s %s\n' "$(date '+%F %T %Z')" "$1"
            }
            read_state() {
              if [ -r "$state_file" ]; then
                ${pkgs.coreutils}/bin/cat "$state_file" || true
                return
              fi
              printf 'unknown'
            }
            state_file="${idleStateFile}"
            runtime_dir="${runtimeDir}"

            state="$(read_state)"
            log "midnight check state=$state file=$state_file"
            if [ "$state" != "idle" ]; then
              log "not idle at 00:00, exiting"
              exit 0
            fi

            ${pkgs.util-linux}/bin/runuser -u ${primaryUser.name} -- env \
              XDG_RUNTIME_DIR="$runtime_dir" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
              ${pkgs.libnotify}/bin/notify-send \
              "Midnight auto-shutdown" \
              "Idle detected. Shutting down in 1 minute unless activity resumes." \
              || true
            log "idle at 00:00, notification sent, waiting 60s"
            ${pkgs.coreutils}/bin/sleep 60

            state_after="$(read_state)"
            log "post-wait check state=$state_after file=$state_file"
            if [ "$state_after" = "idle" ]; then
              log "still idle at 00:01, powering off now"
              ${pkgs.systemd}/bin/systemctl poweroff
            fi
            log "activity resumed before 00:01, skipping shutdown"
          '';
        };
        startAt = "*-*-* 00:00:00";
      };
    };
}
