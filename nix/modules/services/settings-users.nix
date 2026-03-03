{ config, ... }:
let
  cfg = config.flake;
  account = cfg.accounts.rafiq;
  inherit (account) username;
  secretName = "${username}/password";
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        users.mutableUsers = false;
        users.users.${account.username} = {
          description = account.fullName;
          uid = account.nixosUid;
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [
            account.sshPublicKey
          ];
          hashedPasswordFile = config.sops.secrets.${secretName}.path;
        };
        sops.secrets.${secretName} = {
          sopsFile = cfg.paths.root + "/sops/${username}.yaml";
          neededForUsers = true;
        };
      };
    modules.darwin.default = {
      system.primaryUser = account.username;
      users.knownUsers = [ account.username ];
      users.users.${account.username} = {
        home = "/Users/${account.username}";
        uid = account.darwinUid;
        openssh.authorizedKeys.keys = [
          account.sshPublicKey
        ];
      };
    };
  };
}
