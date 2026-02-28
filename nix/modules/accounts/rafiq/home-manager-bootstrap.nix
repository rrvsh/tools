{ config, inputs, ... }:
let
  cfg = config.flake;
  inherit (cfg.accounts.rafiq) username;
in
{
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
            imports = [ cfg.modules.homeManager.rafiq ];
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
          cfg.modules.darwin.rafiq
        ];
        home-manager = {
          backupFileExtension = "bak";
          overwriteBackup = true;
          useUserPackages = true;
          useGlobalPkgs = true;
          users.${username} = {
            imports = [ cfg.modules.homeManager.rafiq ];
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
