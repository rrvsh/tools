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
      { pkgs, ... }:
      {
        home.packages = [
          (pkgs.prismlauncher.override {
            jdks = [ pkgs.jdk25 ];
          })
        ];
      };
  };
}
