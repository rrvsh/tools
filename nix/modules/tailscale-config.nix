{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
in
{
  config.flake.modules.darwin.tailscale-config = {
    services.tailscale.enable = true;
  };
  config.flake.modules.nixos.tailscale-config =
    { config, ... }:
    {
      services.tailscale = {
        enable = true;
        authKeyFile = config.sops.secrets."tailscale/authkey".path;
      };
      sops.secrets."tailscale/authkey".sopsFile = root + "/sops/tailscale.yaml";
    };
}
