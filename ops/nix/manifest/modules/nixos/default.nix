{ config, inputs, ... }:
let
  inherit (config.flake.paths) secrets;
in
{
  flake.modules.nixos.default =
    {
      hostName,
      hostConfig,
      config,
      ...
    }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      networking.hostName = hostName;
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [ "https://nix-community.cachix.org" ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        trusted-substituters = [ "https://nix-community.cachix.org" ];
      };
      nixpkgs.hostPlatform.system = "${hostConfig.arch}-linux";
      security.sudo.wheelNeedsPassword = false;
      services = {
        openssh.enable = true;
        tailscale = {
          authKeyFile = config.sops.secrets."keys/tailscale".path;
          enable = true;
        };
      };
      sops = {
        age.sshKeyPaths = [ "/home/rafiq/.ssh/id_ed25519" ];
        secrets = {
          "keys/tailscale".sopsFile = secrets + /keys.yaml;
          "rafiq/hashedPassword" = {
            neededForUsers = true;
            sopsFile = secrets + /users.yaml;
          };
        };
      };
      system.stateVersion = "25.11";
      users = {
        groups.users.gid = 100;
        mutableUsers = false;
        users.rafiq = {
          extraGroups = [ "wheel" ];
          hashedPasswordFile = config.sops.secrets."rafiq/hashedPassword".path;
          isNormalUser = true;
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
          ];
        };
      };
    };
}
