{ config, lib, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
in
{
  config.flake = {
    modules.nixos.tailscale = lib.mkMerge [
      (
        { config, ... }:
        lib.mkIf (config ? sops) {
          sops.secrets."tailscale/authkey" = {
            sopsFile = root + "/sops/tailscale.yaml";
          };
          services.tailscale = {
            authKeyFile = config.sops.secrets."tailscale/authkey".path;
          };
        }
      )
      {
        services.tailscale.enable = true;
      }
    ];
    modules.darwin.tailscale = {
      services.tailscale.enable = true;
    };

  };
}
