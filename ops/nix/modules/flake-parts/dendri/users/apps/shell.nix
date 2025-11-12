{
  lib,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs hasAttr listToAttrs;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) any;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
  userShells = mapAttrsToList (_: value: value.apps.shell) cfg.users.users;
in
{
  flake.users.userOptions.apps.shell = mkOption { type = enum [ "fish" ]; };
  flake.modules = {
    nixos = mapAttrs (
      username: userConfig:
      (
        { config, pkgs, ... }:
        {
          assertions = [
            {
              assertion = any (pkg_name: hasAttr pkg_name config.programs) userShells;
              message = "users.users.<name>.shell must be set to a valid shell name.";
            }
          ];
          users.users.${username}.shell = pkgs.${userConfig.apps.shell};
          programs = listToAttrs (
            map (x: {
              name = x;
              value.enable = true;
            }) userShells
          );
        }
      )
    ) cfg.users.users;
    darwin = mapAttrs (
      username: userConfig:
      (
        { config, pkgs, ... }:
        {
          assertions = [
            {
              assertion = any (pkg_name: hasAttr pkg_name config.programs) userShells;
              message = "users.users.<name>.shell must be set to a valid shell name.";
            }
          ];
          users.users.${username}.shell = pkgs.${userConfig.apps.shell};
          programs = listToAttrs (
            map (x: {
              name = x;
              value.enable = true;
            }) userShells
          );
        }
      )
    ) cfg.users.users;
    homeManager = mapAttrs (
      _: userConfig:
      (
        { config, ... }:
        {
          assertions = [
            {
              assertion = any (pkg_name: hasAttr pkg_name config.programs) userShells;
              message = "users.users.<name>.shell must be set to a valid shell name.";
            }
          ];
          programs.${userConfig.apps.shell}.enable = true;
        }
      )
    ) cfg.users.users;
  };
}
