{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  inherit (lib.options) mkOption;
  inherit (lib.types) path;
in
{
  options.flake.paths = {
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
}
