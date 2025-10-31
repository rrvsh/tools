{ lib, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  flake.modules.nixos.default =
    { hostName, manifest, ... }:
    mkIf (hostName == manifest.externals.nginx.node) {
      networking.firewall.allowedTCPPorts = [
        80 # HTTP
        443 # HTTPS
      ];
      services.nginx.enable = true;
    };
}
