{ inputs, ... }:
let
  inherit (builtins) toString;
in
{
  flake.modules.nixos.rrv-sh =
    { config, ... }:
    {
      imports = [ inputs.rrv-sh.nixosModules.default ];
      services.rrv-sh.enable = true;
      services.nginx.virtualHosts."rrv.sh" = {
        addSSL = true;
        useACMEHost = "rrv.sh";
        acmeRoot = null; # needed for DNS validation
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.rrv-sh.port}";
        };
      };
    };
}
