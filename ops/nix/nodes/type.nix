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
in
{
  flake.modules.nixos.default =
    { hostConfig, ... }:
    {
      imports = [
        inputs.disko.nixosModules.default
        inputs.nixos-facter-modules.nixosModules.facter
        config.flake.diskoConfigurations.${hostConfig.type}
      ];
      config = mkMerge [
        {
          facter.report = fromJSON (readFile "${facter}/${hostConfig.type}.json");
        }
        (mkIf (hostConfig.type == "rpi4b") {
          boot.loader.grub.enable = false;
          boot.loader.generic-extlinux-compatible.enable = true;
        })
      ];
    };
}
