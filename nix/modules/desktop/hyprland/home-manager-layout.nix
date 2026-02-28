{
  config.flake.modules.homeManager.rafiq = {
    wayland.windowManager.hyprland.settings = {
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
    };
  };
}
