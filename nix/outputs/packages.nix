{ config, inputs, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    let
      # Windows mouse acceleration script for Hyprland
      hyprland-windows-accel = pkgs.writeScriptBin "hyprland-windows-accel" ''
        #!/usr/bin/env bash
        # Apply Windows mouse acceleration to all pointer devices
        # Usage: hyprland-windows-accel [device-name]
        #
        # Environment variables:
        #   DEVICE_DPI              - Mouse DPI (default: 1000)
        #   SCREEN_DPI              - Screen DPI (auto-calculated: ~130 for 34" 4K)
        #   SCREEN_DIAGONAL_INCHES  - Screen diagonal (default: 34)
        #   SCREEN_SCALING_FACTOR   - Hyprland scale (auto-detected)
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

        export SCREEN_DIAGONAL_INCHES=''${SCREEN_DIAGONAL_INCHES:-34}
        export DEVICE_DPI=''${DEVICE_DPI:-1000}
        export SENSITIVITY_FACTOR=''${SENSITIVITY_FACTOR:-6}

        WINDOWS_ACCEL_PY="${
          config.flake.paths.root + /nix/modules/desktop/scripts/hyprland-windows-accel.py
        }"

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
          ${pkgs.hyprland}/bin/hyprctl devices -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '.mice[].name' 2>/dev/null | while read -r device; do
            [ -n "$device" ] && apply_accel "$device"
          done
        fi
      '';
    in
    {
      packages = {
        site-bin = pkgs.rustPlatform.buildRustPackage {
          name = "site";
          src = config.flake.paths.root + /rs;
          cargoLock.lockFile = config.flake.paths.root + /rs/Cargo.lock;
        };
        site-image = pkgs.dockerTools.buildLayeredImage {
          name = "site";
          tag = "latest";
          contents = [
            self'.packages.site-bin
            pkgs.dockerTools.binSh
          ];
          config = {
            Env = [
              "SITE_CONTENT_DIR=${inputs.site-content}"
              "STATIC_DIR=${config.flake.paths.root + /rs/site/static}"
            ];
            Entrypoint = [
              "/bin/sh"
              "-c"
            ];
            Cmd = [ "/bin/site" ];
          };
        };
        inherit hyprland-windows-accel;
      };
    };
}
