{ lib, ... }:
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      wayland.windowManager.hyprland.settings = {
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
}
