{ lib, config, ... }:
let
  common = pkg: builtins.elem (lib.strings.getName pkg) config.flake.allowedUnfreePackages;
in
{
  options.flake.allowedUnfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };
  config.flake.modules.nixos.default = {
    nixpkgs.config.allowUnfreePredicate = common;
  };
  config.flake.modules.darwin.default = {
    nixpkgs.config.allowUnfreePredicate = common;
  };
}
