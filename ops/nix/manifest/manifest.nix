{ config, ... }:
let
  cfg = config.flake;
in
{
  flake.manifest = {
    externals.nginx = {
      node = "veil";
    };
    nodes.nixos = {
      veil = {
        arch = "aarch64";
        createImage = true;
        modules = with cfg.modules.nixos; [ rrv-sh ];
        proxies = [
          {
            domain = "rrv.sh";
            port = 2309;
          }
        ];
      };
    };
  };
}
