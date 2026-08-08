{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    nixos.cursor-themes = {
      home-manager.sharedModules = [ cfg.modules.homeManager.cursor-themes ];
    };
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

                        state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
                        state_file="$state_home/cursor-theme"
                        default_size=32

                        theme_paths() {
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

                        list_themes() {
                          theme_paths | while IFS= read -r base; do
                            [ -d "$base" ] || continue
                            find -L "$base" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | while IFS= read -r directory; do
                              [ -d "$directory/cursors" ] || continue
                              [ -d "$directory/hyprcursors" ] || continue
                              id=$(basename "$directory")
                              name=$(sed -n 's/^Name=//p' "$directory/index.theme" 2>/dev/null | head -n 1 || true)
                              [ -n "$name" ] || name=$id
                              echo "$id|$name"
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
                          # Apps that ignore the XCURSOR_THEME variable follow the `default`
                          # icon theme and inherit its target. Refresh that chain so non-env
                          # GTK/Qt/XWayland clients follow a switch too.
                          for base in "''${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons"; do
                            mkdir -p "$base/default"
                            cat > "$base/default/index.theme" <<EOF
            [Icon Theme]
            Name=Default
            Comment=Default Cursor Theme
            Inherits=$theme
            EOF
                          done
                          mkdir -p "$state_home"
                          {
                            echo "$theme"
                            echo "$size"
                          } > "$state_file"
                        }

                        case ''${1:-restore} in
                          list) list_themes ;;
                          set) [ $# -ge 2 ] || { echo 'usage: cursorctl set THEME [SIZE]' >&2; exit 2; }; apply_theme "$2" "''${3:-$default_size}" ;;
                          restore)
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
                            ;;
                          desktop-entry)
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
                            ;;
                          *) echo 'usage: cursorctl {list|set|restore|desktop-entry}' >&2; exit 2 ;;
                        esac
          '';
        };
      in
      {
        home = {
          # cursorControl must be on PATH so the desktop actions
          # (`Exec=cursorctl set ...`) can invoke it by name.
          packages = [
            cursorControl
          ];
          # Symlink each theme from the package into the canonical search path
          # XDG_DATA_HOME/icons (here ~/.local/share/icons). cursorctl finds
          # themes by searching that path, so no store path is baked into it.
          # Every theme (including pixel-cursors) is installed the same way;
          # the active one is selected at runtime by cursorctl.
          file = builtins.listToAttrs (
            map (theme: {
              name = ".local/share/icons/${theme}";
              value.source = "${cursorPackage}/share/icons/${theme}";
            }) cursorPackage.themeIds
          );
          # Desktop Actions are generated from installed dual-format themes. This
          # keeps the launcher extensible without a second theme registry.
          activation.cursorThemeDesktopEntry = config.lib.dag.entryAfter [ "writeBoundary" ] ''
            mkdir -p "$HOME/.local/share/applications"
            ${cursorControl}/bin/cursorctl desktop-entry > "$HOME/.local/share/applications/cursor-theme.desktop"
          '';
          # Login default before Hyprland runs `cursorctl restore`.
          sessionVariables = {
            XCURSOR_THEME = "pixel-cursors";
            XCURSOR_SIZE = "32";
            HYPRCURSOR_THEME = "pixel-cursors";
            HYPRCURSOR_SIZE = "32";
          };
        };
        wayland.windowManager.hyprland.extraConfig = ''
          hl.on("hyprland.start", function()
            hl.exec_cmd("${cursorControl}/bin/cursorctl restore")
          end)
        '';
      };
  };
}
