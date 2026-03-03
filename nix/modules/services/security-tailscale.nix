{ config, ... }:
let
  cfg = config.flake;
  account = cfg.accounts.rafiq;
  inherit (cfg.paths) root;
  authKeySecretName = "${account.username}/tailscale-authkey";
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        services.tailscale.enable = true;
        services.tailscale.authKeyFile = config.sops.secrets.${authKeySecretName}.path;
        sops.secrets.${authKeySecretName} = {
          sopsFile = root + "/sops/${account.username}.yaml";
        };
      };
    modules.darwin.default = {
      services.tailscale.enable = true;
    };
  };
}
