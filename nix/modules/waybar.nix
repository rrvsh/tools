{ config, inputs, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.nixos.waybar =
    { pkgs, ... }:
    {
      home-manager.sharedModules = [ cfg.modules.homeManager.waybar ];
      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        monocraft
      ];
    };
  config.flake.modules.homeManager.waybar =
    { pkgs, ... }:
    let
      waybarPeek = inputs.waybar-peek.packages.${pkgs.stdenv.hostPlatform.system}.waybar-peek;
    in
    {
      wayland.windowManager.hyprland.extraConfig = ''
        hl.on("hyprland.start", function()
          hl.exec_cmd("waybar")
          hl.exec_cmd("${waybarPeek}/bin/waybar_peek")
        end)
      '';
      xdg.configFile = {
        "waybar/power_menu.xml".text = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <interface>
            <object class="GtkMenu" id="menu">
              <child>
                <object class="GtkMenuItem" id="win11-reboot">
                  <property name="label">Reboot to Windows 11</property>
                </object>
              </child>
            </object>
          </interface>
        '';
        "waybar/scripts/current-task" = {
          executable = true;
          text = ''
            #!${pkgs.bash}/bin/bash
            minutes=$((10#$(${pkgs.coreutils}/bin/date +%H) * 60 + 10#$(${pkgs.coreutils}/bin/date +%M)))

            if (( minutes >= 360 && minutes < 480 )); then
              echo chill
            elif (( minutes >= 480 && minutes < 600 )); then
              echo study
            elif (( minutes >= 600 && minutes < 840 )); then
              echo work
            elif (( minutes >= 840 && minutes < 960 )); then
              echo chill
            elif (( minutes >= 960 && minutes < 1080 )); then
              echo work
            elif (( minutes >= 1080 && minutes < 1260 )); then
              echo chill
            else
              echo free
            fi
          '';
        };
      };
      programs.waybar = {
        enable = true;
        style = ''
          window#waybar {
            background: transparent;
          }

          #clock,
          #custom-current-task,
          #custom-power {
            background: #000000;
            color: #ffffff;
            border: 1px solid #ffffff;
            border-radius: 9999px;
            padding: 3px 8px;
            margin: 4px 0;
            font-family: "Monocraft";
            font-size: 12px;
            font-weight: 400;
            font-style: normal;
          }

          menu {
            border-radius: 12px;
            background: #000000;
            color: #ffffff;
            border: 1px solid #ffffff;
            font-family: "Monocraft";
            font-size: 12px;
            font-weight: 400;
            padding: 4px;
            margin-top: 6px;
            margin-left: 6px;
          }

          menuitem {
            border-radius: 8px;
            font-family: "Monocraft";
            font-size: 12px;
            font-weight: 400;
            margin: 2px;
            padding: 4px 8px;
          }
        '';
        settings = [
          {
            layer = "overlay";
            exclusive = false;
            start_hidden = true;
            ipc = true;
            on-sigusr1 = "hide";
            on-sigusr2 = "show";
            modules-left = [ "custom/current-task" ];
            modules-center = [ "clock" ];
            modules-right = [ "custom/power" ];
            clock = {
              format = "{:%H:%M}";
              tooltip = false;
            };
            "custom/current-task" = {
              exec = "~/.config/waybar/scripts/current-task";
              interval = 60;
              tooltip = false;
            };
            "custom/power" = {
              format = "⏻";
              tooltip = false;
              menu = "on-click";
              menu-file = "~/.config/waybar/power_menu.xml";
              menu-actions."win11-reboot" = "sudo systemctl reboot --boot-loader-entry windows_11-pro.conf";
            };
          }
        ];
      };
    };
}
