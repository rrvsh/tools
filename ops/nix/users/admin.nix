{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) attrNames attrValues;
  inherit (lib.types) str;
  inherit (lib.options) mkOption;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) elemAt;
  manifestAdmin = elemAt (attrValues (
    filterAttrs (_: value: value.primary or false) cfg.manifest.users.users
  )) 0;
in
{
  options.flake.manifest.users = {
    admin.username = mkOption { type = str; };
    admin.email = mkOption { type = str; };
  };
  config.flake.manifest.users = {
    admin.username = elemAt (attrNames (
      filterAttrs (_: value: value.primary or false) cfg.manifest.users.users
    )) 0;
    admin.email = manifestAdmin.email;
  };
}
