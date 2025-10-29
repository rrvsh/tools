{ config, lib, ... }:
let
  inherit (builtins) concatLists map;
  inherit (lib.trivial) pipe;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (cfg.paths) secrets;
  cfg = config.flake;
in
{
  flake.modules.nixos.provides-nginx =
    { config, hostName, ... }:
    {
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
      services.nginx = {
        enable = true;
        virtualHosts = pipe cfg.manifest.nodes.nixos [
          (
            attrs:
            mapAttrsToList (
              nodeName: nodeValue: map (vHostConfig: vHostConfig // { node = nodeName; }) nodeValue.needs.nginx
            ) attrs
          )
          concatLists
          # collect needs.nginx enriched with node name
          (map (needsConfig: {
            ${needsConfig.domain} = {
              addSSL = true;
              useACMEHost = needsConfig.domain;
              acmeRoot = null; # needed for DNS validation
              locations."/" = {
                proxyPass = "http://${
                  if needsConfig.node == hostName then "localhost" else needsConfig.node
                }:${toString needsConfig.port}";
              };
            };
          }))
          (xs: lib.foldl' (acc: x: acc // x) { } xs)
          # module that can be imported into a provider
        ];
      };
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
