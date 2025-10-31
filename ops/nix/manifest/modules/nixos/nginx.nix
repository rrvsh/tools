{ lib, ... }:
let
  inherit (builtins)
    toString
    map
    concatLists
    listToAttrs
    ;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.modules) mkMerge mkIf;
  inherit (lib.trivial) pipe;
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
    { hostName, manifest, ... }:
    mkMerge [
      (mkIf (hostName == manifest.externals.nginx.node) {
        networking.firewall.allowedTCPPorts = [
          80 # HTTP
          443 # HTTPS
        ];
        services.nginx.enable = true;
        services.nginx.virtualHosts = mkVHostConfig manifest;
      })
    ];
}
