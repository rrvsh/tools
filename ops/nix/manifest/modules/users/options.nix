{ lib, ... }:
let
  inherit (lib.types) attrsOf submodule;
  inherit (lib.options) mkOption mkEnableOption;
in
{
  options.flake.manifest.users = mkOption {
    type = attrsOf (submodule {
      options.primary = mkEnableOption "";
    });
  };
}
