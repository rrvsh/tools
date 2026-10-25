{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
in
{
  config.flake.modules.nixos.slskd =
    { config, primaryUser, ... }:
    let
      sopsFile = root + "/sops/slskd.yaml";
    in
    {
      services.slskd = {
        enable = true;
        group = "users";
        environmentFile = config.sops.templates."slskd.env".path;
        openFirewall = false;
        settings = {
          directories = {
            incomplete = "/var/lib/slskd/incomplete";
            downloads = "/var/lib/slskd/downloads";
          };
          flags.force_share_scan = false;
          rooms = [ ];
          shares = {
            directories = [ ];
            filters = [ ];
          };
          soulseek = {
            description = "rrv.sh";
            listen_port = 50300;
          };
          web = {
            ip_address = "127.0.0.1";
            port = 5030;
            https.disabled = true;
          };
        };
      };

      sops = {
        secrets = {
          "slskd/soulseek-username".sopsFile = sopsFile;
          "slskd/soulseek-password".sopsFile = sopsFile;
          "slskd/web-username".sopsFile = sopsFile;
          "slskd/web-password" = {
            inherit sopsFile;
            owner = primaryUser.name;
          };
        };
        templates."slskd.env" = {
          owner = "slskd";
          group = "users";
          mode = "0400";
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
          StateDirectoryMode = "0750";
          UMask = "0007";
          WorkingDirectory = "${config.services.slskd.package}/lib/slskd";
        };
        tmpfiles.rules = [
          "d /var/lib/slskd/incomplete 0770 slskd users -"
          "d /var/lib/slskd/downloads 0770 slskd users -"
        ];
      };
    };
}
