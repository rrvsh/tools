{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) fromJSON readFile;
  inherit (cfg.paths) facter;
  inherit (lib.modules) mkMerge mkIf;
  inherit (lib.lists) optional;
in
{
  flake.modules.nixos.default =
    { hostConfig, ... }:
    {
      imports = [
        inputs.disko.nixosModules.default
        inputs.nixos-facter-modules.nixosModules.facter
      ]
      ++ optional (!hostConfig.isVm or true) (
        config.flake.diskoConfigurations.${hostConfig.type} { inherit (hostConfig) device; }
      );
      config = mkIf (!hostConfig.isVm or true) (mkMerge [
        {
          facter.report = fromJSON (readFile "${facter}/${hostConfig.type}.json");
        }
        (mkIf (hostConfig.type == "rpi4b") {
          boot.loader.grub.enable = false;
          boot.loader.generic-extlinux-compatible.enable = true;
        })
      ]);
    };
}
