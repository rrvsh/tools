{ inputs, lib, ... }:
{
  config.flake.modules.nixos.hyprland =
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
  config.flake.modules.homeManager.rafiq =
    { osConfig, pkgs, ... }:
    {
      wayland.windowManager.hyprland = {
        enable = osConfig.programs.hyprland.enable or false;
        package = null;
        portalPackage = null;
        settings = {
          monitor = [
            "HDMI-A-1, 3840x2160@160, auto, 2"
            ", preferred, auto, 1"
          ];
          input = {
            accel_profile = builtins.concatStringsSep " " [
              "custom"
              "0.5"
              "0.0"
              "0.5"
              "1.0"
              "1.5"
            ];
            sensitivity = 1.0;
          };
          general = {
            gaps_in = 0;
            gaps_out = 0;
          };
          bind = [
            ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"
            ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
            ", F7, exec, ${lib.getExe pkgs.ddcutil} setvcp 10 - 5"
            ", F8, exec, ${lib.getExe pkgs.ddcutil} setvcp 10 + 5"
            "ALT_CTRL, 1, exec, ghostty"
            "ALT_CTRL, 2, exec, firefox"
            "ALT_CTRL, 3, exec, steam"
            "ALT_CTRL, 4, exec, obs"
            "ALT_CTRL, w, killactive"
            "ALT, TAB, cyclenext"
            "ALT, H, movefocus, l"
            "ALT, J, movefocus, d"
            "ALT, K, movefocus, u"
            "ALT, L, movefocus, r"
            "ALT_SUPER, H, workspace, -1"
            "ALT_SUPER, L, workspace, +1"
            "ALT_SHIFT, H, movewindow, l"
            "ALT_SHIFT, J, movewindow, d"
            "ALT_SHIFT, K, movewindow, u"
            "ALT_SHIFT, L, movewindow, r"
            "ALT_SHIFT_SUPER, H, movetoworkspace, -1"
            "ALT_SHIFT_SUPER, L, movetoworkspace, +1"
          ];
          bindc = [ "ALT_SHIFT, mouse:272, togglefloating" ];
          bindm = [
            "ALT, mouse:272, movewindow"
            "ALT, mouse:273, resizewindow 2"
            "ALT_SHIFT, mouse:273, resizewindow 1"
          ];
        };
      };
    };
}
