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
      (
        { pkgs, ... }:
        {
          image.fileName = "nixos-25-11-aarch64-veil.img";
          sdImage.compressImage = false;
          nixpkgs.hostPlatform.system = "aarch64-linux";
          system.stateVersion = "25.11";
          environment.systemPackages = with pkgs; [
            nginx
          ];
          services = {
            openssh.enable = true;
            nginx.enable = true;
            nginx.virtualHosts."_".root = "/var/www/veil";
          };
          users.users.rafiq = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
            ];
          };
          systemd.services."nginx".preStart = ''
            mkdir -p /var/www/veil
            echo "<h1>Welcome to Veil!</h1>" > /var/www/veil/index.html
          '';
        }
      )
    ];
  };
}
