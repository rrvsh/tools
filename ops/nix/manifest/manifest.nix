{ config, ... }:
let
  cfg = config.flake;
in
{
  flake.manifest = {
    nodes.nixos = {
      veil = {
        arch = "aarch64";
        createImage = true;
        needs.nginx = [
          {
            domain = "rrv.sh";
            port = 2309;
            type = "proxy";
          }
        ];
        modules = with cfg.modules.nixos; [
          provides-nginx
          rrv-sh
        ];
      };
    };
  };
}
