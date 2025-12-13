{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types)
    attrs
    str
    attrsOf
    submodule
    ;
in
{
  options.flake.users.userOptions.apps = mkOption { type = attrs; };
  options.flake.users.users = mkOption {
    type = attrsOf (submodule {
      options = {
        primary = mkEnableOption ""; # used for users.admin option
        fullName = mkOption { type = str; };
        email = mkOption { type = str; };
        pubkey = mkOption { type = str; };
        defaultBranchName = mkOption {
          type = str;
          default = "main";
        };
        apps = mkOption { type = submodule { options = cfg.users.userOptions.apps; }; };
      };
    });
  };
  config.flake.modules.darwin.default =
    { config, ... }:
    (import ./_darwin.nix {
      inherit
        cfg
        config
        inputs
        lib
        ;
    });
}
