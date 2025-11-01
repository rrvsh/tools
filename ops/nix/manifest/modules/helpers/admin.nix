{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) attrNames;
  inherit (lib.types) str;
  inherit (lib.options) mkOption;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) elemAt;
in
{
  options.flake.manifest.helpers.admin.username = mkOption { type = str; };
  config.flake.manifest.helpers.admin.username = elemAt (attrNames (
    filterAttrs (_: value: value.primary or false) cfg.manifest.users
  )) 0;
}
