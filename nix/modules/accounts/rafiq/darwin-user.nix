{ config, ... }:
let
  account = config.flake.accounts.rafiq;
in
{
  config.flake.modules.darwin.default = {
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
}
