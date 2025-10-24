{ config, ... }:
let
  cfg = config.flake;
in
{
  flake.manifest = {
    users.rafiq = { };
    hosts.darwin.solomon = { };
    hosts.nixos = {
      veil = {
        arch = "aarch64";
        createImage = true;
        modules = with cfg.modules.nixos; [
          reverse-proxy
          rrv-sh
        ];
      };
    };
  };
}
