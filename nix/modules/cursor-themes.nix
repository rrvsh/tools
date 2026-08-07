{ config, lib, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.cursor-themes ];
  };
in
{
  config.flake.modules = {
    darwin.cursor-themes = { };
    nixos.cursor-themes = osModule;
    homeManager.cursor-themes =
      { config, pkgs, ... }:
      let
        cursorPackage = cfg.packages.${pkgs.stdenv.hostPlatform.system}.pixel-cursor-themes;
        cursorControl = pkgs.writeShellApplication {
          name = "cursorctl";
          runtimeInputs = with pkgs; [
            coreutils
            findutils
            gawk
            glib
            gsettings-desktop-schemas
            hyprland
            gnused
          ];
          text = ''
            set -eu

            builtin_theme_path=${lib.escapeShellArg "${cursorPackage}/share/icons"}
            state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
            state_file="$state_home/cursor-theme"
            default_size=32

            theme_paths() {
              echo "$builtin_theme_path"
              echo "''${XDG_DATA_HOME:-$HOME/.local/share}/icons"
              echo "$HOME/.icons"
              if [ -n "''${XCURSOR_PATH:-}" ]; then
                printf '%s' "$XCURSOR_PATH" | awk -v RS=: '{print}'
              fi
              if [ -n "''${XDG_DATA_DIRS:-}" ]; then
                printf '%s' "$XDG_DATA_DIRS" | awk -v RS=: '{print}' | while IFS= read -r path; do
                  echo "$path/icons"
                done
              fi
            }

            theme_directory() {
              wanted=$1
              while IFS= read -r base; do
                [ -d "$base/$wanted/cursors" ] || continue
                [ -d "$base/$wanted/hyprcursors" ] || continue
                echo "$base/$wanted"
                return 0
              done < <(theme_paths)
              return 1
            }

            theme_display_name() {
              directory=$1
              name=$(sed -n 's/^Name=//p' "$directory/index.theme" 2>/dev/null | head -n 1 || true)
              if [ -n "$name" ]; then
                echo "$name"
              else
                basename "$directory"
              fi
            }

            list_themes() {
              theme_paths | while IFS= read -r base; do
                [ -d "$base" ] || continue
                find "$base" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | while IFS= read -r directory; do
                  [ -d "$directory/cursors" ] || continue
                  [ -d "$directory/hyprcursors" ] || continue
                  id=$(basename "$directory")
                  echo "$id|$(theme_display_name "$directory")"
                done
              done | awk -F '|' '!seen[$1]++'
            }

            apply_theme() {
              theme=$1
              size=''${2:-$default_size}
              directory=$(theme_directory "$theme")
              [ -n "$directory" ] || { echo "cursor theme not found: $theme" >&2; exit 1; }
              hyprctl setcursor "$theme" "$size" >/dev/null
              # Hyprland changes its compositor cursor immediately. GSettings
              # covers GTK clients, which do not all follow compositor state.
              gsettings set org.gnome.desktop.interface cursor-theme "$theme"
              gsettings set org.gnome.desktop.interface cursor-size "$size"
              hyprctl keyword envd "HYPRCURSOR_THEME,$theme" >/dev/null
              hyprctl keyword envd "HYPRCURSOR_SIZE,$size" >/dev/null
              hyprctl keyword envd "XCURSOR_THEME,$theme" >/dev/null
              hyprctl keyword envd "XCURSOR_SIZE,$size" >/dev/null
              mkdir -p "$state_home"
              {
                echo "$theme"
                echo "$size"
              } > "$state_file"
            }

            restore_theme() {
              theme=""; size=$default_size
              if [ -r "$state_file" ]; then
                IFS= read -r theme < "$state_file" || true
                IFS= read -r size < <(sed -n '2p' "$state_file") || true
              fi
              [ -n "$theme" ] || theme=pixel-cursors
              case "$size" in ""|*[!0-9]*) size=$default_size ;; esac
              if ! theme_directory "$theme" >/dev/null; then
                theme=pixel-cursors
              fi
              apply_theme "$theme" "$size"
            }

            desktop_entry() {
              themes=$(list_themes)
              actions="restore;"
              while IFS='|' read -r id display; do
                actions="$actions$id;"
              done <<< "$themes"
              echo '[Desktop Entry]'
              echo 'Type=Application'
              echo 'Name=Cursor Theme'
              echo 'Comment=Choose the active cursor theme'
              echo 'Exec=cursorctl restore'
              echo "Actions=$actions"
              echo '[Desktop Action restore]'
              echo 'Name=Restore saved theme'
              echo 'Exec=cursorctl restore'
              while IFS='|' read -r id display; do
                echo "[Desktop Action $id]"
                echo "Name=$display"
                echo "Exec=cursorctl set $id"
                echo
              done <<< "$themes"
            }

            case ''${1:-restore} in
              list) list_themes ;;
              set) [ $# -ge 2 ] || { echo 'usage: cursorctl set THEME [SIZE]' >&2; exit 2; }; apply_theme "$2" "''${3:-$default_size}" ;;
              restore) restore_theme ;;
              desktop-entry) desktop_entry ;;
              *) echo 'usage: cursorctl {list|set|restore|desktop-entry}' >&2; exit 2 ;;
            esac
          '';
        };
      in
      {
        home = {
          packages = [
            cursorPackage
            cursorControl
          ];
          pointerCursor = {
            enable = true;
            package = cursorPackage;
            name = "pixel-cursors";
            size = 32;
            gtk.enable = true;
            hyprcursor.enable = true;
            x11.enable = true;
          };
          # Desktop Actions are generated from installed dual-format themes. This
          # keeps the launcher extensible without a second theme registry.
          activation.cursorThemeDesktopEntry = config.lib.dag.entryAfter [ "writeBoundary" ] ''
            mkdir -p "$HOME/.local/share/applications"
            ${cursorControl}/bin/cursorctl desktop-entry > "$HOME/.local/share/applications/cursor-theme.desktop"
          '';
        };
        wayland.windowManager.hyprland.extraConfig = ''
          hl.on("hyprland.start", function()
            hl.exec_cmd("${cursorControl}/bin/cursorctl restore")
          end)
        '';
      };
  };
}
