# Collects every string in config.flake.allowedUnfreePackages (merged from any nix/*.nix file via flake-parts)
# and feeds nixpkgs.config.allowUnfreePredicate (the function nixpkgs calls to decide if an unfree package
# is allowed) with a predicate that returns true when the package name is in that merged list. On Darwin
# this lets us allow overlays like firefox-bin (unfree) without duplicating logic per host/user.
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
    modules.nixos.default.nixpkgs.config.allowUnfreePredicate =
      pkg: elem (getName pkg) cfg.allowedUnfreePackages;
    modules.darwin.default.nixpkgs.config.allowUnfreePredicate =
      pkg: elem (getName pkg) cfg.allowedUnfreePackages;
  };
}
