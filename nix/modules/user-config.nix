{ inputs, ... }:
let
  common = {
    home-manager = {
      backupFileExtension = "bak";
      overwriteBackup = true;
      useUserPackages = true;
      useGlobalPkgs = true;
      sharedModules = [ { home.stateVersion = "26.05"; } ];
    };
  };
in
{
  config.flake.modules.nixos.user-config = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    users.mutableUsers = false;
  }
  // common;
  config.flake.modules.darwin.user-config = {
    imports = [ inputs.home-manager.darwinModules.home-manager ];
  }
  // common;
}
