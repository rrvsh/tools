{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins)
    toString
    map
    listToAttrs
    attrNames
    foldl'
    ;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
  inherit (lib.types)
    listOf
    deferredModule
    submodule
    str
    port
    enum
    ;
  proxyApps = foldl' (
    acc: n:
    acc
    // {
      n.node = (acc.${n.node} or [ ]) ++ n.apps;
    }
  ) { } cfg.externals.nginx.proxies;
in
{
  options.flake.externals.nginx.proxies = mkOption {
    type = listOf (submodule {
      options = {
        node = mkOption { type = enum (attrNames cfg.nodes.nixos); };
        domain = mkOption { type = str; };
        port = mkOption { type = port; };
        apps = mkOption { type = listOf deferredModule; };
      };
    });
    default = [ ];
  };
  config.flake.modules.nixos.default =
    { hostName, ... }:
    {
      imports = proxyApps.${hostName} or [ ];
      config = mkIf (hostName == cfg.externals.nginx.node) {
        services.nginx.virtualHosts = pipe cfg.externals.nginx.proxies [
          (map (proxy: {
            name = proxy.domain;
            value = {
              addSSL = cfg.externals.nginx.ssl.enable;
              useACMEHost = if cfg.externals.nginx.ssl.enable then proxy.domain else null;
              acmeRoot = null; # needed for DNS validation
              locations."/".proxyPass = "http://${
                if (proxy.node == cfg.externals.nginx.node) then "localhost" else proxy.node
              }:${toString proxy.port}";
            };
          }))
          listToAttrs
        ];
      };
    };
}
