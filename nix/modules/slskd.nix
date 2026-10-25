{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
in
{
  config.flake.modules.nixos.slskd =
    { config, lib, ... }:
    let
      directories = {
        downloads = "/var/lib/slskd/downloads";
        incomplete = "/var/lib/slskd/incomplete";
      };
      sopsFile = root + "/sops/slskd.yaml";
    in
    {
      services.slskd = {
        enable = true;
        # The default group is slskd. Use users so the primary user and MusicGrabber can access completed files.
        group = "users";
        environmentFile = config.sops.templates."slskd.env".path;
        openFirewall = true;
        settings = {
          inherit directories;
          shares.directories = [ directories.downloads ];
        };
      };

      sops = {
        secrets = {
          "slskd/soulseek-username".sopsFile = sopsFile;
          "slskd/soulseek-password".sopsFile = sopsFile;
          "slskd/web-username".sopsFile = sopsFile;
          "slskd/web-password".sopsFile = sopsFile;
        };
        templates."slskd.env" = {
          owner = "slskd";
          # Restart slskd after credential changes so it reloads the rendered environment file.
          restartUnits = [ "slskd.service" ];
          content = ''
            SLSKD_SLSK_USERNAME=${config.sops.placeholder."slskd/soulseek-username"}
            SLSKD_SLSK_PASSWORD=${config.sops.placeholder."slskd/soulseek-password"}
            SLSKD_USERNAME=${config.sops.placeholder."slskd/web-username"}
            SLSKD_PASSWORD=${config.sops.placeholder."slskd/web-password"}
          '';
        };
      };

      systemd = {
        services.slskd.serviceConfig = {
          # Nixpkgs makes every shared directory read-only, but this directory also receives completed downloads.
          ReadOnlyPaths = lib.mkForce [ ];
          StateDirectoryMode = "0750";
          UMask = "0007";
          WorkingDirectory = "${config.services.slskd.package}/lib/slskd";
        };
        tmpfiles.rules = [
          "d ${directories.incomplete} 0770 slskd users -"
          "d ${directories.downloads} 0770 slskd users -"
        ];
      };
    };
}
