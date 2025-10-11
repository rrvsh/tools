{ config, ... }:
let
  cfg = config.flake;
in
{
  flake = {
    manifest.hosts.nixos.veil = {
      arch = "aarch64";
      createImage = true;
      modules = with cfg.modules.nixos; [
        reverse-proxy
        rrv-sh
      ];
    };
    modules.nixos.veil =
      { pkgs, config, ... }:
      {
        nixpkgs.hostPlatform.system = "aarch64-linux";
        services = {
          openssh.enable = true;
          tailscale = {
            enable = true;
            authKeyFile = config.sops.secrets."keys/tailscale".path;
          };
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
        security = {
          sudo.wheelNeedsPassword = false;
        };
        sops.secrets = {
          "rafiq/hashedPassword".neededForUsers = true;
          "rafiq/hashedPassword".sopsFile = ./users.yaml;
          "keys/tailscale".sopsFile = ./keys.yaml;
        };
      };
  };
}
