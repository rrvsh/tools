{ inputs, lib, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optional;
in
{
  flake.modules.nixos.default =
    { hostName, hostConfig, ... }:
    {
      imports = optional hostConfig.createImage "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-${hostConfig.arch}.nix";
      config = mkIf hostConfig.createImage {
        image.fileName = "nixos-25-11-${hostConfig.arch}-${hostName}.img";
        sdImage.compressImage = false;
      };
    };
}
