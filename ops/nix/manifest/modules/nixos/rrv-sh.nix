{ config, ... }:
let
  inherit (config.flake.paths) www;
in
{
  flake.modules.nixos.rrv-sh = {
    services.nginx.virtualHosts."rrv.sh" = {
      addSSL = true;
      useACMEHost = "rrv.sh";
      acmeRoot = null; # needed for DNS validation
      locations."/".root = "${www}/rrv.sh";
    };
  };
}
