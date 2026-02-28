{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.nixos.default =
    { config, ... }:
    {
      users.users.rafiq.hashedPasswordFile = config.sops.secrets."rafiq/password".path;
      sops.secrets."rafiq/password" = {
        sopsFile = cfg.paths.root + /sops/rafiq.yaml;
        neededForUsers = true;
      };
    };
}
