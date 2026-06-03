{ inputs, ... }:
let
  common = {
    home-manager = {
      backupFileExtension = "bak";
      overwriteBackup = true;
      useUserPackages = true;
      useGlobalPkgs = true;
    };
  };
in
{
  config.flake.modules.nixos.home-manager-config = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
  }
  // common;
  config.flake.modules.darwin.home-manager-config = {
    imports = [ inputs.home-manager.darwinModules.home-manager ];
  }
  // common;
}
