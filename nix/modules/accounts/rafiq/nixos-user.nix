{ config, ... }:
let
  account = config.flake.accounts.rafiq;
in
{
  config.flake.modules.nixos.default = {
    users.mutableUsers = false;
    users.users.${account.username} = {
      description = account.fullName;
      uid = account.nixosUid;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        account.sshPublicKey
      ];
    };
  };
}
