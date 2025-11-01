{
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg) manifest;
  inherit (builtins) mapAttrs;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) filterAttrs;
in
{
  flake.images = (mapAttrs (name: _: cfg.nixosConfigurations.${name}.config.system.build.sdImage)) (
    filterAttrs (_: value: value.createImage) manifest.nodes.nixos
  );
  flake.modules.nixos.default =
    { hostName, hostConfig, ... }:
    {
      imports = [ "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-${hostConfig.arch}.nix" ];
      config = mkIf hostConfig.createImage {
        image.fileName = "nixos-25-11-${hostConfig.arch}-${hostName}.img";
        sdImage.compressImage = false;
      };
    };
}
