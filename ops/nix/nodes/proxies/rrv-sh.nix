{ inputs, ... }:
{
  flake.modules.nixos.rrv-sh = {
    imports = [ inputs.rrv-sh.nixosModules.default ];
    services.rrv-sh.enable = true;
    networking.firewall.allowedTCPPorts = [ 2309 ];
  };
}
