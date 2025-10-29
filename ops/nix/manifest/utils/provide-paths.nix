{ lib, config, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) path;
  inherit (config.flake.paths) root;
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
