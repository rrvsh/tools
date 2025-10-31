{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    attrsOf
    submodule
    str
    bool
    path
    ;
in
{
  options.flake = {
    manifest.nodes.nixos = mkOption {
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
