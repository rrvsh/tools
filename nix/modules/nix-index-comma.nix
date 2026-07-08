{ config, inputs, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.nix-index-comma ];
  };
in
{
  config.flake.modules = {
    darwin.nix-index-comma = osModule;
    nixos.nix-index-comma = osModule;
    homeManager.nix-index-comma = {
      imports = [ inputs.nix-index-database.homeModules.nix-index ];
      programs = {
        nix-index.enable = true;
        nix-index-database.comma.enable = true;
      };
    };
  };
}
