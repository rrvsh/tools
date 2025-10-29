{ config, ... }:
let
  inherit (config.flake.paths) secrets;
in
{
  flake.modules.nixos.reverse-proxy =
    { config, ... }:
    {
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
      services.nginx.enable = true;
      users.users.nginx.extraGroups = [ "acme" ];
      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "rafiq@rrv.sh";
          dnsProvider = "cloudflare";
          credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets."keys/cloudflare".path;
        };
        certs."rrv.sh".extraDomainNames = [ "*.rrv.sh" ];
      };
      sops.secrets."keys/cloudflare".sopsFile = secrets + /keys.yaml;
    };
}
