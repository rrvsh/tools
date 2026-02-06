{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        services.tailscale.enable = true;
        services.tailscale.authKeyFile = config.sops.secrets."rafiq/tailscale-authkey".path;
        sops.secrets."rafiq/tailscale-authkey" = {
          sopsFile = root + /sops/rafiq.yaml;
        };
      };
    modules.darwin.default = {
      services.tailscale.enable = true;
    };
  };
}
