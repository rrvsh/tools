{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) elem;
  inherit (lib.options) mkOption;
  inherit (lib.types) listOf str;
  inherit (lib.strings) getName;
in
{
  options.flake.allowedUnfreePackages = mkOption { type = listOf str; };
  config.flake = {
    modules.darwin.leaf.nixpkgs.config.allowUnfreePredicate =
      pkg: elem (getName pkg) cfg.allowedUnfreePackages;
  };
}
