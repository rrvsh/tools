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
      nixpkgs.hostPlatform.system = "${hostConfig.arch}-linux";
      networking.hostName = hostName;
      services = {
        openssh.enable = true;
        tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets."keys/tailscale".path;
        };
      };
      sops.secrets."keys/tailscale".sopsFile = secrets + /keys.yaml;
      system.stateVersion = "25.11";
      imports = [ inputs.sops-nix.nixosModules.sops ];
      security.sudo.wheelNeedsPassword = false;
      users = {
        mutableUsers = false;
        groups.users.gid = 100;
        users.rafiq = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          hashedPasswordFile = config.sops.secrets."rafiq/hashedPassword".path;
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
          ];
        };
      };
      sops.secrets = {
        "rafiq/hashedPassword".neededForUsers = true;
        "rafiq/hashedPassword".sopsFile = secrets + /users.yaml;
      };
      #FIXME: Don't hardcode the home path
      sops.age.sshKeyPaths = [ "/home/rafiq/.ssh/id_ed25519" ];
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [ "https://nix-community.cachix.org" ];
        trusted-substituters = [ "https://nix-community.cachix.org" ];
        trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
      };
    };
}
