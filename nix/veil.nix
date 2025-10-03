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
      inputs.sops-nix.nixosModules.sops
      (
        { pkgs, config, ... }:
        {
          image.fileName = "nixos-25-11-aarch64-veil.img";
          sdImage.compressImage = false;
          nixpkgs.hostPlatform.system = "aarch64-linux";
          system.stateVersion = "25.11";
          nix.settings = {
            substituters = [ "https://nix-community.cachix.org" ];
            trusted-substituters = [ "https://nix-community.cachix.org" ];
            trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
          };
          services = {
            openssh.enable = true;
            nginx.enable = true;
            nginx.virtualHosts."_".root = ../www/rrv.sh;
          };
          users = {
            mutableUsers = false;
            groups.users.gid = 100;
            users.rafiq = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              packages = with pkgs; [ git ];
              hashedPasswordFile = config.sops.secrets."rafiq/hashedPassword".path;
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
              ];
            };
          };
          security.sudo.wheelNeedsPassword = false;
          networking.hostName = "veil";
          networking.firewall.allowedTCPPorts = [
            80
            443
          ];
          sops = {
            age.sshKeyPaths = [ "/home/rafiq/.ssh/id_ed25519" ];
            secrets."rafiq/hashedPassword" = {
              neededForUsers = true;
              sopsFile = ./users.yaml;
            };
          };
        }
      )
    ];
  };
}
