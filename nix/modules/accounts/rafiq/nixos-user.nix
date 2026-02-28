{
  config.flake.modules.nixos.default = {
    users.mutableUsers = false;
    users.users.rafiq = {
      description = "Mohammad Rafiq";
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
      ];
    };
  };
}
