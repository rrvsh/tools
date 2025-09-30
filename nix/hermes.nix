{
  lib,
  inputs,
  config,
  ...
}:
{
  flake.images.hermes = config.flake.nixosConfigurations.hermes.config.system.build.sdImage;
  flake.nixosConfigurations.hermes = lib.nixosSystem {
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      {
        image.fileName = "nixos-25-11-aarch64-hermes.img";
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
