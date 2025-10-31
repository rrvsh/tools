{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  inherit (builtins) attrNames;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    deferredModule
    attrsOf
    submodule
    str
    bool
    path
    enum
    listOf
    port
    ;
in
{
  options.flake = {
    manifest = {
      externals.nginx = mkOption {
        type = submodule {
          options = {
            node = mkOption { type = enum (attrNames cfg.manifest.nodes.nixos); };
          };
        };
      };
      nodes.nixos = mkOption {
        type = attrsOf (submodule {
          options = {
            arch = mkOption { type = str; };
            createImage = mkOption {
              type = bool;
              default = false;
            };
            proxies = mkOption {
              type = listOf (submodule {
                options = {
                  domain = mkOption { type = str; };
                  port = mkOption { type = port; };
                };
              });
              default = [ ];
            };
            modules = mkOption {
              type = listOf deferredModule;
              default = [ ];
            };
          };
        });
      };
    };
    paths = {
      root = mkOption {
        type = path;
        readOnly = true;
      };
      secrets = mkOption {
        type = path;
        default = root + "/ops/sops";
      };
      www = mkOption {
        type = path;
        default = root + "/src/www";
      };
    };
  };
}
