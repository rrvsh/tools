{
  flake.modules.nixos.users =
    { config, ... }:
    {
      security.sudo.wheelNeedsPassword = false;
      users = {
        mutableUsers = false;
        groups.users.gid = 100;
        users.rafiq = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          hashedPasswordFile = config.sops.secrets."rafiq/hashedPassword".path;
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
          ];
        };
      };
      sops.secrets = {
        "rafiq/hashedPassword".neededForUsers = true;
        "rafiq/hashedPassword".sopsFile = ../../users.yaml;
      };
    };
}
