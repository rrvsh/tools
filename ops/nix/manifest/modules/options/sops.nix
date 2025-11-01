# provide sops to the whole flake
{
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  inherit (lib.options) mkEnableOption;
in
{
  options.flake.manifest.options.sops.enable = mkEnableOption "";
  config.flake = {
    modules.nixos.sops-common = {
      needs = [ cfg.modules.nixos.users ];
    };
  };
}
