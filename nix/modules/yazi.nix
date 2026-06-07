{ config, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.yazi ];
  };
in
{
  config.flake.modules = {
    darwin.yazi = osModule;
    nixos.yazi = osModule;
    homeManager.yazi =
      { pkgs, config, ... }:
      {
        home.shellAliases.t = config.programs.yazi.shellWrapperName;
        programs.yazi = {
          enable = true;
          shellWrapperName = "yy";
          package = pkgs.yazi.override {
            extraPackages = [ pkgs.exiftool ];
          };
        };
      };
  };
}
