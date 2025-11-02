{ config, lib, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) secrets;
  inherit (builtins) pathExists;
  inherit (lib.modules) mkMerge mkIf;
in
{
  flake.modules.nixos.default = mkMerge [
    { services.tailscale.enable = true; }
    (mkIf cfg.secrets.sops.enable {
      assertions = [
        {
          assertion = pathExists "${secrets}/keys.yaml";
          message = "You must have created `ops/sops/keys.yaml` to enable tailscale integration.";
        }
      ];
      services.tailscale.authKeyFile = config.sops.secrets."keys/tailscale".path or null;
      sops.secrets."keys/tailscale".sopsFile = secrets + /keys.yaml;
    })
  ];
}
