{
  lib,
  inputs,
  config,
  ...
}:
{
  flake.images.veil = config.flake.nixosConfigurations.veil.config.system.build.sdImage;
  flake.nixosConfigurations.veil = lib.nixosSystem {
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      {
        image.fileName = "nixos-25-11-aarch64-veil.img";
        sdImage.compressImage = false;
        nixpkgs.hostPlatform.system = "aarch64-linux";
        system.stateVersion = "25.11";
        services.openssh.enable = true;
        users.users.rafiq = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
          ];
        };
      }
    ];
  };
}
