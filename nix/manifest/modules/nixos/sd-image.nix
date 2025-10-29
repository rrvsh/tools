{ inputs, ... }:
{
  flake.modules.nixos.sd-image =
    { hostName, hostConfig, ... }:
    {
      imports = [
        "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-${hostConfig.arch}.nix"
      ];
      config = {
        image.fileName = "nixos-25-11-${hostConfig.arch}-${hostName}.img";
        sdImage.compressImage = false;
      };
    };
}
