{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins)
    attrNames
    foldl'
    listToAttrs
    map
    toString
    ;
  inherit (lib.types)
    enum
    listOf
    port
    str
    submodule
    ;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
in
{
  options.flake.externals.nginx.proxies = mkOption {
    type = listOf (submodule {
      options = {
        apps = mkOption { type = enum (attrNames cfg.modules.nixos); };
        domain = mkOption { type = str; };
        node = mkOption { type = enum (attrNames cfg.nodes.nixos); };
        port = mkOption { type = port; };
      };
    });
    default = [ ];
  };
  config.flake.modules.nixos.default =
    { hostName, ... }:
    {
      imports =
        (foldl' (
          acc: n:
          acc
          // {
            n.node = (acc.${n.node} or [ ]) ++ (map (app: cfg.modules.nixos.${app}) n.apps);
          }
        ) { } cfg.externals.nginx.proxies).${hostName} or [ ];
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
