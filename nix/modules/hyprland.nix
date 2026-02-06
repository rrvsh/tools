{ inputs, ... }:
{
  config.flake = {
    modules.nixos.hyprland =
      { config, pkgs, ... }:
      {
        imports = [ inputs.hyprland.nixosModules.default ];
        programs = {
          hyprland = {
            enable = true;
            xwayland.enable = true;
            package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
            portalPackage =
              inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
          };
          dconf.enable = true;
        };
        security.polkit.enable = true;
        assertions = [
          {
            assertion = config.networking.hostName != "";
            message = "Hyprland module expects a hostName.";
          }
        ];
        xdg.portal.enable = true;
        xdg.portal.extraPortals = [ config.programs.hyprland.portalPackage ];
        environment.sessionVariables.NIXOS_OZONE_WL = "1";
      };
    modules.homeManager.rafiq =
      { osConfig, ... }:
      {
        wayland.windowManager.hyprland = {
          enable = osConfig.programs.hyprland.enable or false;
          package = null;
          portalPackage = null;
          settings = {
            "$mod" = "SUPER";
            bind = [
              ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
              ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"
              ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
              ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
            ];
          };
        };
      };
  };
}
