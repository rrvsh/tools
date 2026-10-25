{ inputs, ... }:
let
  packageFor = pkgs: inputs.musicgrabber.packages.${pkgs.stdenv.hostPlatform.system}.musicgrabber;
in
{
  config.flake.modules = {
    darwin.musicgrabber =
      {
        config,
        pkgs,
        primaryUser,
        ...
      }:
      let
        home = config.users.users.${primaryUser.name}.home;
        package = packageFor pkgs;
      in
      {
        launchd.user.agents.musicgrabber.serviceConfig = {
          ProgramArguments = [
            "${pkgs.writeShellScript "musicgrabber" ''
              set -euo pipefail
              export SLSKD_URL=http://127.0.0.1:5030
              export SLSKD_USER="$(<${config.sops.secrets."slskd/web-username".path})"
              export SLSKD_PASS="$(<${config.sops.secrets."slskd/web-password".path})"
              export SLSKD_DOWNLOADS_PATH=${pkgs.lib.escapeShellArg "${home}/Library/Application Support/slskd/downloads"}
              export SLSKD_MOVE_COMPLETED=false
              export SOURCE_SOULSEEK_ENABLED=true
              exec ${package}/bin/musicgrabber
            ''}"
          ];
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          EnvironmentVariables = {
            HOME = home;
            # Change the plist when credentials change so launchd restarts MusicGrabber with the new values.
            SLSKD_SECRETS_HASH = config.sops.secrets."slskd/web-username".sopsFileHash;
          };
        };
      };

    nixos.musicgrabber =
      {
        config,
        pkgs,
        primaryUser,
        ...
      }:
      let
        home = config.users.users.${primaryUser.name}.home;
        package = packageFor pkgs;
      in
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
          environment.HOME = home;
          serviceConfig = {
            User = primaryUser.name;
            Group = "users";
            EnvironmentFile = config.sops.templates."musicgrabber.env".path;
            ExecStart = "${package}/bin/musicgrabber";
            Restart = "on-failure";
            UMask = "0077";
          };
        };
      };
  };
}
