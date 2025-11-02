{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) fromJSON readFile elem;
  inherit (cfg.paths) facter;
  inherit (lib.modules) mkMerge mkIf;
  inherit (lib.strings) getName;
in
{
  flake.modules.nixos.default =
    { hostConfig, pkgs, ... }:
    {
      imports = [
        inputs.disko.nixosModules.default
        inputs.nixos-facter-modules.nixosModules.facter
        (config.flake.diskoConfigurations.${hostConfig.type} { inherit (hostConfig) device; })
      ];
      config = mkMerge [
        {
          facter.report = fromJSON (readFile "${facter}/${hostConfig.type}.json");
        }
        (mkIf (hostConfig.type == "rpi4b") {
          boot.loader.grub.enable = false;
          boot.loader.generic-extlinux-compatible.enable = true;
        })
        (mkIf (hostConfig.type == "nephalem") {
          boot.kernelPackages = pkgs.linuxPackages_latest;
          services.xserver.videoDrivers = [ "nvidia" ];
          hardware.nvidia = {
            modesetting.enable = true;
            powerManagement.enable = false;
            open = false;
            nvidiaSettings = true;
            package = pkgs.linuxPackages_latest.nvidiaPackages.stable;
          };
          nixpkgs.config.allowUnfreePredicate =
            pkg:
            elem (getName pkg) [
              "nvidia-settings"
              "nvidia-x11"
            ];
        })
      ];
    };
}
