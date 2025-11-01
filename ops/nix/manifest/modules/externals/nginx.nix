{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins)
    toString
    map
    concatLists
    listToAttrs
    ;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.modules) mkMerge mkIf;
  inherit (lib.trivial) pipe;
  inherit (cfg.paths) secrets;
  mkVHostConfig =
    manifest:
    pipe manifest.nodes.nixos [
      # enrich each proxy attrset with the node name
      (mapAttrsToList (nodeName: nodeConfig: map (x: x // { node = nodeName; }) nodeConfig.proxies))
      # combine all proxy attrsets in the manifest
      concatLists
      # construct virtual host config for proxies
      (map (proxy: {
        name = proxy.domain;
        value = {
          inherit (manifest.externals.nginx) addSSL;
          useACMEHost = if manifest.externals.nginx.addSSL then proxy.domain else null;
          acmeRoot = null; # needed for DNS validation
          locations."/".proxyPass = "http://${
            if (proxy.node == manifest.externals.nginx.node) then "localhost" else proxy.node
          }:${toString proxy.port}";
        };
      }))
      listToAttrs
    ];
in
{
  flake.modules.nixos.default =
    {
      hostName,
      manifest,
      config,
      ...
    }:
    mkIf (hostName == manifest.externals.nginx.node) (mkMerge [
      {
        networking.firewall.allowedTCPPorts = [
          80 # HTTP
          443 # HTTPS
        ];
        services.nginx.enable = true;
        services.nginx.virtualHosts = mkVHostConfig manifest;
      }
      (mkIf manifest.externals.nginx.addSSL {
        users.users.nginx.extraGroups = [ "acme" ];
        sops.secrets."keys/cloudflare".sopsFile = secrets + /keys.yaml;
        security.acme = {
          acceptTerms = true;
          defaults = {
            email = "rafiq@rrv.sh";
            dnsProvider = "cloudflare";
            credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets."keys/cloudflare".path;
          };
          certs."rrv.sh".extraDomainNames = [ "*.rrv.sh" ];
        };
      })
    ]);
}
