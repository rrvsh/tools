{ config, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.prismlauncher ];
  };
in
{
  config.flake.modules = {
    darwin.prismlauncher = osModule;
    nixos.prismlauncher = osModule;
    homeManager.prismlauncher =
      { config, pkgs, ... }:
      {
        xdg.desktopEntries.gtnh = {
          name = "GregTech New Horizons";
          icon = "${config.home.homeDirectory}/.local/share/PrismLauncher/instances/GT_New_Horizons_2.8.4_Java_17-25/icon.png";
          exec = "prismlauncher --launch GT_New_Horizons_2.8.4_Java_17-25";
        };
        home.packages = [
          (pkgs.prismlauncher.override {
            jdks = [ pkgs.jdk25 ];
          })
        ];
      };
  };
}
