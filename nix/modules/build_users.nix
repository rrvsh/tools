{
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake = {
    modules.darwin.default =
      { config, ... }:
      {
        imports = [
          inputs.home-manager.darwinModules.home-manager
          cfg.modules.darwin.rafiq
        ];
        # disable asking for password for sudo
        security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
        system.primaryUser = "rafiq";
        users.knownUsers = [ "rafiq" ];
        users.users.rafiq = {
          home = "/Users/rafiq";
          # first user created is always 501
          uid = 501;
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
          ];
        };
        home-manager = {
          # keep only one backup of files
          backupFileExtension = "bak";
          overwriteBackup = true;
          useGlobalPkgs = true;
          users.rafiq = {
            imports = [ cfg.modules.homeManager.rafiq ];
            home = {
              username = "rafiq";
              homeDirectory = config.users.users.rafiq.home;
              stateVersion = "25.11";
            };
          };
        };
      };
  };
}
