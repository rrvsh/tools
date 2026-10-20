{ inputs, config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.nixos.hyprland =
    { config, pkgs, ... }:
    {
      imports = [ inputs.hyprland.nixosModules.default ];
      home-manager.sharedModules = [ cfg.modules.homeManager.hyprland ];
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
      xdg.portal = {
        enable = true;
        extraPortals = [ config.programs.hyprland.portalPackage ];
      };
    };
  config.flake.modules.homeManager.hyprland =
    { pkgs, ... }:
    {
      wayland.windowManager.hyprland = {
        enable = true;
        configType = "lua";
        package = null;
        portalPackage = null;
        plugins = [
          inputs.hypr-dynamic-cursors.packages.${pkgs.stdenv.hostPlatform.system}.hypr-dynamic-cursors
        ];
        settings = {
          monitor = [
            {
              output = "HDMI-A-1";
              mode = "3840x2160@160";
              position = "auto";
              scale = 2;
            }
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = 2;
            }
          ];
          config = {
            input.sensitivity = 1.0;
            general = {
              gaps_in = 0;
              gaps_out = 0;
              border_size = 0;
            };
            plugin.dynamic_cursors = {
              mode = "tilt";
              tilt = {
                limit = 3000;
                activation = "linear";
                window = 80;
                full = 25;
              };
              shake = {
                enabled = true;
                threshold = 3.0;
                base = 3.0;
                speed = 0;
                timeout = 500;
                effects = true;
              };
            };
          };
        };
      };
    };
}
