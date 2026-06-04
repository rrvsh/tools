{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  sharedOsConfig =
    { config, pkgs, ... }:
    {
      nix.settings.trusted-users = [ "rafiq" ];
      users.users.rafiq.shell = pkgs.fish; # TODO: figure out how to decouple from user
      home-manager.users.rafiq = {
        home = {
          username = "rafiq";
          homeDirectory = config.users.users.rafiq.home;
        };
        programs.git.settings = {
          user.name = "Mohammad Rafiq";
          user.email = "rafiq@rrv.sh";
          init.defaultBranch = "prime";
        };
      };
    };
in
{
  config.flake.modules.nixos.user-rafiq =
    { config, ... }:
    {
      imports = [
        sharedOsConfig
        cfg.modules.nixos.user-config
      ];
      programs.fish.enable = true;
      users.users.rafiq = {
        description = "Mohammad Rafiq";
        uid = 1000;
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
        ];
        hashedPasswordFile = config.sops.secrets."rafiq/password".path;
      };
      sops.secrets."rafiq/password" = {
        sopsFile = root + "/sops/rafiq.yaml";
        neededForUsers = true;
      };
    };
  config.flake.modules.darwin.user-rafiq = {
    imports = [
      sharedOsConfig
      cfg.modules.darwin.user-config
    ];
    programs.fish.enable = true;
    system.primaryUser = "rafiq";
    users.knownUsers = [ "rafiq" ];
    users.users.rafiq = {
      home = "/Users/rafiq";
      uid = 501;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
      ];
    };
  };
}
