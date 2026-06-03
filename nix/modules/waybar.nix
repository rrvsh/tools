{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
in
{
  config.flake.modules.nixos.waybar =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        monocraft
      ];
    };
  config.flake.modules.homeManager.waybar =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    lib.mkIf pkgs.stdenv.isLinux {
      xdg.configFile = {
        "hypr/scripts/waybar_peek.py" = {
          source = root + /scripts/waybar_peek.py;
          executable = true;
        };
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
      };
      programs.waybar = {
        enable = true;
        systemd.enable = true;
        style = ''
          window#waybar {
            background: transparent;
          }

          #clock,
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
            modules-left = [ ];
            modules-center = [ "clock" ];
            modules-right = [ "custom/power" ];
            clock = {
              format = "{:%H:%M}";
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
      systemd.user.services = {
        waybar.Unit.ConditionEnvironment = lib.mkForce [ ];
        waybar-peek = lib.mkIf (osConfig.programs.hyprland.enable or false) {
          Unit = {
            Description = "waybar_peek auto-hide helper for Hyprland";
            After = [
              "graphical-session.target"
              "waybar.service"
            ];
            Wants = [
              "graphical-session.target"
              "waybar.service"
            ];
          };
          Service = {
            ExecStart = "${pkgs.python3}/bin/python3 ${config.xdg.configHome}/hypr/scripts/waybar_peek.py";
            Restart = "always";
            RestartSec = 1;
            Environment = [
              "WAYBAR_PEEK_SHOW_PX=5"
              "WAYBAR_PEEK_HIDE_PX=120"
              "WAYBAR_PEEK_POLL=0.1"
            ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
