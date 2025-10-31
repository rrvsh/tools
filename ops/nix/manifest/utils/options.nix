{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  inherit (builtins) attrNames;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    attrsOf
    submodule
    str
    bool
    path
    enum
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
