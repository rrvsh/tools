{ config, lib, ... }:
let
  inherit (builtins) concatLists map;
  inherit (lib.trivial) pipe;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (cfg.paths) secrets;
  cfg = config.flake;

  # collect needs.nginx enriched with node name
  needsNginx = pipe cfg.manifest.nodes.nixos [
    (
      attrs:
      mapAttrsToList (
        nodeName: nodeValue: map (vHostConfig: vHostConfig // { node = nodeName; }) nodeValue.needs.nginx
      ) attrs
    )
    concatLists
  ];

  # module that can be imported into a provider
  providesNginxConfig = pipe needsNginx [
    (map (needsConfig: {
      services.nginx.virtualHosts.${needsConfig.domain} = {
        addSSL = true;
        useACMEHost = needsConfig.domain;
        acmeRoot = null; # needed for DNS validation
        locations."/" = {
          proxyPass = "http://${needsConfig.node}:${toString needsConfig.port}";
        };
      };
    }))
    (xs: lib.foldl' (acc: x: acc // x) { } xs)
  ];

in
{
  flake.modules.nixos.provides-nginx =
    { config, ... }:
    providesNginxConfig
    // {
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
