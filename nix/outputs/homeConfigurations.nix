{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg.accounts.rafiq) username;
  inherit (lib.options) mkOption;
  inherit (lib.types) int str;
in
{
  options.flake.accounts.rafiq = {
    username = mkOption {
      type = str;
      default = "rafiq";
      description = "Primary account username for rafiq.";
    };
    fullName = mkOption {
      type = str;
      default = "Mohammad Rafiq";
      description = "Full display name for rafiq account metadata.";
    };
    email = mkOption {
      type = str;
      default = "rafiq@rrv.sh";
      description = "Primary email address for rafiq account metadata.";
    };
    nixosUid = mkOption {
      type = int;
      default = 1000;
      description = "Numeric UID for rafiq on NixOS.";
    };
    darwinUid = mkOption {
      type = int;
      default = 501;
      description = "Numeric UID for rafiq on Darwin.";
    };
    sshPublicKey = mkOption {
      type = str;
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
      description = "Primary SSH public key for rafiq account access.";
    };
  };
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        imports = [
          inputs.home-manager.nixosModules.home-manager
          cfg.modules.nixos.rafiq
        ];
        home-manager = {
          backupFileExtension = "bak";
          overwriteBackup = true;
          useUserPackages = true;
          useGlobalPkgs = true;
          users.${username} = {
            imports = [ cfg.modules.homeManager.${username} ];
            home = {
              inherit username;
              homeDirectory = config.users.users.${username}.home;
              stateVersion = "25.11";
            };
          };
        };
      };
    modules.darwin.default =
      { config, ... }:
      {
        imports = [
          inputs.home-manager.darwinModules.home-manager
          cfg.modules.darwin.${username}
        ];
        home-manager = {
          backupFileExtension = "bak";
          overwriteBackup = true;
          useUserPackages = true;
          useGlobalPkgs = true;
          users.${username} = {
            imports = [ cfg.modules.homeManager.${username} ];
            home = {
              inherit username;
              homeDirectory = config.users.users.${username}.home;
              stateVersion = "25.11";
            };
          };
        };
      };
  };
}
