{ config, ... }:
let
  cfg = config.flake;
in
{
  flake.manifest = {
    options = {
      sops.enable = true;
    };
    externals.nginx = {
      node = "veil";
      addSSL = true;
    };
    nodes.nixos = {
      nephalem = {
        arch = "x86_64";
      };
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
