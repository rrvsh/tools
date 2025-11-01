{ lib, config, ... }:
let
  cfg = config.flake;
  modCfg = config.flake.manifest.externals.nginx;
  inherit (builtins)
    toString
    map
    concatLists
    listToAttrs
    attrNames
    ;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
  inherit (lib.types) enum;
in
{
  options.flake.manifest.externals.nginx.node = mkOption {
    type = enum (attrNames cfg.manifest.nodes.nixos);
  };
  config.flake.modules.nixos.default =
    { hostName, ... }:
    mkIf (hostName == modCfg.node) {
      networking.firewall.allowedTCPPorts = [
        80 # HTTP
        443 # HTTPS
      ];
      services.nginx.enable = true;
      services.nginx.virtualHosts = pipe cfg.manifest.nodes.nixos [
        # enrich each proxy attrset with the node name
        (mapAttrsToList (nodeName: nodeConfig: map (x: x // { node = nodeName; }) nodeConfig.proxies))
        # combine all proxy attrsets in the manifest
        concatLists
        # construct virtual host config for proxies
        (map (proxy: {
          name = proxy.domain;
          value = {
            addSSL = modCfg.ssl.enable;
            useACMEHost = if modCfg.ssl.enable then proxy.domain else null;
            acmeRoot = null; # needed for DNS validation
            locations."/".proxyPass = "http://${
              if (proxy.node == modCfg.node) then "localhost" else proxy.node
            }:${toString proxy.port}";
          };
        }))
        listToAttrs
      ];
    };
}
