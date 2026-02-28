{
  config.flake.modules.homeManager.rafiq =
    { osConfig, ... }:
    {
      wayland.windowManager.hyprland = {
        enable = osConfig.programs.hyprland.enable or false;
        package = null;
        portalPackage = null;
      };
    };
}
