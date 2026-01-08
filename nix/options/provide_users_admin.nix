{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (lib.types) str;
  inherit (lib.options) mkOption;
  inherit (lib.lists) elemAt;
  primaryUsers = lib.attrsets.filterAttrs (_: value: value.primary or false) cfg.users.users;
in
{
  options.flake.users.admin.username = mkOption {
    internal = true;
    type = str;
  };
  config.flake = {
    users.admin.username = elemAt (builtins.attrNames primaryUsers) 0;
    modules.darwin.default = {
      system.primaryUser = cfg.users.admin.username;
      nix.settings.trusted-users = [ cfg.users.admin.username ];
    };
  };
}
