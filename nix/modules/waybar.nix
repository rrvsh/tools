{
  config.flake = {
    modules.homeManager.rafiq =
      { config, ... }:
      {
        programs.waybar = {
          enable = config.wayland.windowManager.hyprland.enable or false;
          systemd.enable = true;
          style = ''
            window#waybar {
              background: transparent;
              border: none;
              box-shadow: none;
            }

            #clock {
              color: #ffffff;
              background: transparent;
              border: none;
              box-shadow: none;
              padding: 0;
              margin: 0;
            }
          '';
          settings = {
            mainBar = {
              layer = "top";
              position = "top";
              modules-left = [ ];
              modules-center = [ "clock" ];
              modules-right = [ ];
              clock = {
                format = "{:%A, %d/%m/%Y %H:%M:%S}";
                interval = 1;
              };
            };
          };
        };
      };
  };
}
