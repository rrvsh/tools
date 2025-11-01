{ inputs, ... }:
{
  flake.modules.nixos.default =
    { hostName, hostConfig, ... }:
    {
      imports = [ "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-${hostConfig.arch}.nix" ];
      image.fileName = "nixos-25-11-${hostConfig.arch}-${hostName}.img";
      sdImage.compressImage = false;

      users.users.rafiq = {
        extraGroups = [ "wheel" ];
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
        ];
      };
    };
}
