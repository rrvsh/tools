{ inputs, ... }:
{
  config.flake.modules = {
    darwin.musicgrabber =
      {
        config,
        pkgs,
        primaryUser,
        system,
        ...
      }:
      {
        launchd.user.agents.musicgrabber.serviceConfig = {
          ProgramArguments = [
            "${pkgs.writeShellScript "musicgrabber" ''
              set -euo pipefail
              export SLSKD_URL=http://127.0.0.1:5030
              export SLSKD_USER="$(<${config.sops.secrets."slskd/web-username".path})"
              export SLSKD_PASS="$(<${config.sops.secrets."slskd/web-password".path})"
              export SLSKD_DOWNLOADS_PATH=${pkgs.lib.escapeShellArg "${config.users.users.${primaryUser.name}.home}/Library/Application Support/slskd/downloads"}
              export SLSKD_MOVE_COMPLETED=false
              export SOURCE_SOULSEEK_ENABLED=true
              exec ${inputs.musicgrabber.packages.${system}.musicgrabber}/bin/musicgrabber
            ''}"
          ];
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          EnvironmentVariables = {
            HOME = config.users.users.${primaryUser.name}.home;
            # Change the plist when credentials change so launchd restarts MusicGrabber with the new values.
            SLSKD_SECRETS_HASH = config.sops.secrets."slskd/web-username".sopsFileHash;
          };
        };
      };

    nixos.musicgrabber =
      {
        config,
        primaryUser,
        system,
        ...
      }:
      {
        sops.templates."musicgrabber.env" = {
          owner = primaryUser.name;
          restartUnits = [ "musicgrabber.service" ];
          content = ''
            SLSKD_URL=http://127.0.0.1:5030
            SLSKD_USER=${config.sops.placeholder."slskd/web-username"}
            SLSKD_PASS=${config.sops.placeholder."slskd/web-password"}
            SLSKD_DOWNLOADS_PATH=/var/lib/slskd/downloads
            SLSKD_MOVE_COMPLETED=false
            SOURCE_SOULSEEK_ENABLED=true
          '';
        };

        systemd.services.musicgrabber = {
          description = "MusicGrabber music acquisition service";
          after = [
            "network-online.target"
            "slskd.service"
          ];
          wants = [
            "network-online.target"
            "slskd.service"
          ];
          wantedBy = [ "multi-user.target" ];
          environment.HOME = config.users.users.${primaryUser.name}.home;
          serviceConfig = {
            User = primaryUser.name;
            Group = "users";
            EnvironmentFile = config.sops.templates."musicgrabber.env".path;
            ExecStart = "${inputs.musicgrabber.packages.${system}.musicgrabber}/bin/musicgrabber";
            Restart = "on-failure";
            UMask = "0077";
          };
        };
      };
  };
}
