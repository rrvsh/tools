{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) attrNames attrValues;
  inherit (lib.types) str;
  inherit (lib.options) mkOption;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) elemAt;
  manifestAdmin = elemAt (attrValues (
    filterAttrs (_: value: value.primary or false) cfg.manifest.users
  )) 0;
in
{
  options.flake.manifest.helpers.admin.username = mkOption { type = str; };
  options.flake.manifest.helpers.admin.email = mkOption { type = str; };
  config.flake.manifest.helpers.admin.username = elemAt (attrNames (
    filterAttrs (_: value: value.primary or false) cfg.manifest.users
  )) 0;
  config.flake.manifest.helpers.admin.email = manifestAdmin.email;
}
