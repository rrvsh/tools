{ inputs, ... }:
{
  flake.modules.nixos.default =
    { hostName, hostConfig, ... }:
    {
      imports = [ "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-${hostConfig.arch}.nix" ];
      image.fileName = "nixos-25-11-${hostConfig.arch}-${hostName}.img";
      sdImage.compressImage = false;
    };
}
