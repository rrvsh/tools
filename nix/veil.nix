{ config, ... }:
let
  cfg = config.flake;
in
{
  flake = {
    manifest.hosts.nixos.veil = {
      arch = "aarch64";
      createImage = true;
      modules = with cfg.modules.nixos; [
        reverse-proxy
        rrv-sh
      ];
    };
  };
}
