{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) attrNames attrValues;
  inherit (lib.types) str;
  inherit (lib.options) mkOption;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) elemAt;
  adminCfg = elemAt (attrValues (filterAttrs (_: value: value.primary or false) cfg.users.users)) 0;
in
{
  options.flake.users.admin = {
    username = mkOption { type = str; };
    email = mkOption { type = str; };
  };
  config.flake = {
    users.admin = {
      inherit (adminCfg) email;
      username = elemAt (attrNames (filterAttrs (_: value: value.primary or false) cfg.users.users)) 0;
    };
    modules.darwin.default = {
      system.primaryUser = cfg.users.admin.username;
      nix.settings.trusted-users = [ cfg.users.admin.username ];
    };
  };
}
