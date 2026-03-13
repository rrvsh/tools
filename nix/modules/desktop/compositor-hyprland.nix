{ inputs, lib, ... }:
let
  # Path to the Windows mouse acceleration Python script
  accelScript = ./scripts/hyprland-windows-accel.py;
in
{
  config.flake.modules.nixos.hyprland =
    { config, pkgs, ... }:
    let
      # Wrapper script that sets up environment and runs the Python script
      hyprland-windows-accel = pkgs.writeScriptBin "hyprland-windows-accel" ''
        #!/usr/bin/env bash
        # Apply Windows mouse acceleration to all pointer devices
        # Usage: hyprland-windows-accel [device-name]
        #
        # Environment variables (all auto-detected if not set):
        #   DEVICE_DPI              - Mouse DPI (default: 1000, most mice cannot auto-report)
        #   SCREEN_DPI              - Screen DPI (auto-calculated: ~130 for 34" 4K)
        #   SCREEN_DIAGONAL_INCHES  - Screen diagonal (default: 34)
        #   SCREEN_SCALING_FACTOR   - Hyprland scale (auto-detected from hyprctl)
        #   SENSITIVITY_FACTOR      - Windows sens 1-11 (default: 6 = 1.0)

        set -e

        # Handle help flags
        if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
          echo "Usage: hyprland-windows-accel [device-name|help]"
          echo ""
          echo "Apply Windows-style mouse acceleration to Hyprland pointer devices."
          echo ""
          echo "Arguments:"
          echo "  (none)         Apply to all detected mice (default)"
          echo "  device-name    Apply to specific device (run 'hyprctl devices' to list)"
          echo "  help           Show this help message"
          echo ""
          echo "Environment variables:"
          echo "  DEVICE_DPI              - Mouse DPI (default: 1000)"
          echo "  SCREEN_DIAGONAL_INCHES  - Screen diagonal in inches (default: 34)"
          echo "  SENSITIVITY_FACTOR      - Windows sens 1-11 (default: 6 = 1.0)"
          echo ""
          echo "Note: This script requires Hyprland to be running (uses hyprctl)."
          exit 0
        fi

        # 34" 4K monitor DPI calculation:
        # Diagonal pixels = sqrt(3840^2 + 2160^2) = ~4406
        # DPI = 4406 / 34 = ~130
        export SCREEN_DIAGONAL_INCHES=''${SCREEN_DIAGONAL_INCHES:-34}

        # Default mouse DPI (most gaming mice don't report this to the OS)
        # Common values: 400, 800, 1000, 1600, 3200
        export DEVICE_DPI=''${DEVICE_DPI:-1000}

        # Windows sensitivity factor (6 = default/1.0)
        export SENSITIVITY_FACTOR=''${SENSITIVITY_FACTOR:-6}

        WINDOWS_ACCEL_PY="${accelScript}"

        apply_accel() {
          local device="$1"
          echo "Applying Windows mouse acceleration to: $device"
          ${pkgs.python3}/bin/python3 "$WINDOWS_ACCEL_PY" accel_profile "device=$device"
        }

        if [ -n "$1" ]; then
          # Apply to specific device
          apply_accel "$1"
        else
          # Apply to all detected mice
          echo "Detecting mice..."
          ${pkgs.hyprland}/bin/hyprctl devices -j | ${pkgs.jq}/bin/jq -r '.mice[].name' | while read -r device; do
            [ -n "$device" ] && apply_accel "$device"
          done
        fi
      '';
    in
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

      environment.systemPackages = [ hyprland-windows-accel ];
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
      home.packages = [
        # Windows mouse acceleration script - available as 'hyprland-windows-accel' command
        (pkgs.writeScriptBin "hyprland-windows-accel" ''
          #!/usr/bin/env bash
          # Apply Windows mouse acceleration to all pointer devices
          # Usage: hyprland-windows-accel [device-name]

          set -e

          # Handle help flags
          if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
            echo "Usage: hyprland-windows-accel [device-name|help]"
            echo ""
            echo "Apply Windows-style mouse acceleration to Hyprland pointer devices."
            echo ""
            echo "Arguments:"
            echo "  (none)         Apply to all detected mice (default)"
            echo "  device-name    Apply to specific device (run 'hyprctl devices' to list)"
            echo "  help           Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  DEVICE_DPI              - Mouse DPI (default: 1000)"
            echo "  SCREEN_DIAGONAL_INCHES  - Screen diagonal in inches (default: 34)"
            echo "  SENSITIVITY_FACTOR      - Windows sens 1-11 (default: 6 = 1.0)"
            echo ""
            echo "Note: This script requires Hyprland to be running (uses hyprctl)."
            exit 0
          fi

          # 34" 4K monitor DPI calculation:
          # Diagonal pixels = sqrt(3840^2 + 2160^2) = ~4406
          # DPI = 4406 / 34 = ~130
          export SCREEN_DIAGONAL_INCHES=''${SCREEN_DIAGONAL_INCHES:-34}

          # Default mouse DPI (most gaming mice don't report this to the OS)
          export DEVICE_DPI=''${DEVICE_DPI:-1000}

          # Windows sensitivity factor (6 = default/1.0)
          export SENSITIVITY_FACTOR=''${SENSITIVITY_FACTOR:-6}

          WINDOWS_ACCEL_PY="${accelScript}"

          apply_accel() {
            local device="$1"
            echo "Applying Windows mouse acceleration to: $device"
            ${pkgs.python3}/bin/python3 "$WINDOWS_ACCEL_PY" accel_profile "device=$device"
          }

          if [ -n "$1" ]; then
            # Apply to specific device
            apply_accel "$1"
          else
            # Apply to all detected mice
            echo "Detecting mice..."
            ${pkgs.hyprland}/bin/hyprctl devices -j | ${pkgs.jq}/bin/jq -r '.mice[].name' | while read -r device; do
              [ -n "$device" ] && apply_accel "$device"
            done
          fi
        '')
      ];

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
            # Windows-style acceleration applied via exec-once script below
            sensitivity = 1.0;
          };

          exec-once = [
            # Apply Windows mouse acceleration to all detected mice
            "hyprland-windows-accel"
          ];
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
