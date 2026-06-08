{
  config.flake.modules.nixos.gtnh-backups =
    { pkgs, ... }:
    let
      backupDir = "/srv/gtnh-backups";
    in
    {
      systemd = {
        tmpfiles.rules = [ "d ${backupDir} 0750 root root -" ];
        services.gtnh-backup = {
          description = "Backup GTNH server";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "gtnh-backup" ''
              set -euo pipefail

              ts="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
              dest="${backupDir}/gtnh-$ts.tar.zst"

              echo "say Starting server backup" > /run/gtnh-server.stdin || true
              echo "save-all" > /run/gtnh-server.stdin || true
              ${pkgs.coreutils}/bin/sleep 10

              ${pkgs.gnutar}/bin/tar \
                --exclude='/srv/gtnh/backups' \
                -C /srv \
                -I '${pkgs.zstd}/bin/zstd -T0 -10' \
                -cf "$dest" \
                gtnh

              ${pkgs.findutils}/bin/find ${backupDir} \
                -name 'gtnh-*.tar.zst' \
                -type f \
                -mtime +14 \
                -delete

              echo "say Server backup complete" > /run/gtnh-server.stdin || true
            '';
          };
        };
        timers.gtnh-backup = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "03:30";
            Persistent = true;
          };
        };
      };
    };
}
