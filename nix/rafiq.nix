# Contains all configuration personal to Rafiq
# exports modules.{nixos,darwin}.rafiq
# consumed by {nemesis,alpha}.nix
{ config, inputs, ... }:
let
  cfg = config.flake;
  sharedOsConfig =
    { config, pkgs, ... }:
    let
      homeDir = config.users.users.rafiq.home;
    in
    {
      sops.age.sshKeyPaths = [ "${homeDir}/.ssh/id_ed25519" ];
      nix.settings.trusted-users = [ "rafiq" ];
      users.users.rafiq.shell = pkgs.fish;
      home-manager = {
        # back up files in place if found blocking activation
        # instead of aborting
        backupFileExtension = "bak";
        overwriteBackup = true;
        # these help mediate environment conflicts
        useUserPackages = true;
        useGlobalPkgs = true;
        users.rafiq = {
          # import from rafiq/
          imports = [ cfg.modules.homeManager.rafiq ];
          home = {
            username = "rafiq";
            homeDirectory = homeDir;
            stateVersion = "25.11";
          };
        };
      };
    };
in
{
  config.flake.modules.nixos.rafiq =
    { config, ... }:
    {
      imports = [
        sharedOsConfig
        inputs.home-manager.nixosModules.home-manager
        cfg.modules.nixos.fish
      ];
      users.mutableUsers = false;
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
        sopsFile = cfg.paths.root + "/sops/rafiq.yaml";
        neededForUsers = true;
      };
    };
  config.flake.modules.darwin.rafiq = {
    imports = [
      sharedOsConfig
      inputs.home-manager.darwinModules.home-manager
      cfg.modules.darwin.fish
      cfg.modules.darwin.homebrew
    ];
    nix-homebrew.user = "rafiq";
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
