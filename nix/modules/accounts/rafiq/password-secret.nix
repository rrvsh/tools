{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.accounts.rafiq) username;
  secretName = "${username}/password";
in
{
  config.flake.modules.nixos.default =
    { config, ... }:
    {
      users.users.${username}.hashedPasswordFile = config.sops.secrets.${secretName}.path;
      sops.secrets.${secretName} = {
        sopsFile = cfg.paths.root + "/sops/${username}.yaml";
        neededForUsers = true;
      };
    };
}
