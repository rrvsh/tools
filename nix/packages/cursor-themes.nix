{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    let
      themeIds = [
        "cursors-extended"
        "pixel-cursors"
        "pixel-cursor-plus-plus"
        "windows-98-cursors"
      ];
      cursorAliases = {
        default = [
          "left_ptr"
          "arrow"
          "top_left_arrow"
        ];
        pointing_hand = [
          "pointer"
          "hand"
          "pointing_hand"
        ];
        grabbing = [
          "grab"
          "grabbing"
        ];
        ibeam = [
          "text"
          "ibeam"
        ];
        not_allowed = [
          "not-allowed"
          "crossed_circle"
          "no-drop"
        ];
        resize_all = [
          "move"
          "all-scroll"
          "size_all"
        ];
        resize_ew = [
          "e-resize"
          "ew-resize"
          "size_hor"
        ];
        resize_ns = [
          "n-resize"
          "ns-resize"
          "size_ver"
        ];
        resize_nesw = [
          "ne-resize"
          "nesw-resize"
          "size_fdiag"
        ];
        resize_nwse = [
          "nw-resize"
          "nwse-resize"
          "size_bdiag"
        ];
        crosshair = [ "crosshair" ];
        shift = [ "dnd-move" ];
      };
    in
    {
      packages.pixel-cursor-themes = pkgs.stdenvNoCC.mkDerivation {
        pname = "pixel-cursor-themes";
        version = "0.1.0";
        src = root + /assets/cursors;
        nativeBuildInputs = [
          pkgs.hyprcursor
          pkgs.xcur2png
          pkgs.xcursorgen
        ];
        dontBuild = true;
        installPhase = ''
                    runHook preInstall
                    mkdir -p "$out/share/icons"
                    for theme in ${pkgs.lib.escapeShellArgs themeIds}; do
                      source="$PWD/$theme"
                      themeRoot="$out/share/icons/$theme"
                      displayName="$theme"
                      case "$theme" in
                        cursors-extended) displayName="Cursors Extended" ;;
                        pixel-cursors) displayName="Pixel Cursors" ;;
                        pixel-cursor-plus-plus) displayName="Pixel Cursor ++" ;;
                        windows-98-cursors) displayName="Windows 98 Cursors" ;;
                      esac
                      mkdir -p "$themeRoot/cursors" "$themeRoot/hyprcursors"

                      # XCursor is the intentionally simple source format in this package.
                      # hyprcursor-util then converts the compiled result, so the two
                      # formats cannot drift in artwork, hotspots, or animation timing.
                      for role in default pointing_hand grabbing ibeam not_allowed crosshair resize_all resize_ew resize_ns resize_nesw resize_nwse shift; do
                        IFS=, read -r xhot yhot < "$source/$role.hotspot"
                        printf '%s %s %s images/%s.png\n' 32 "$xhot" "$yhot" "$role" > "$source/$role.cfg"
                        ${pkgs.xcursorgen}/bin/xcursorgen -p "$source" "$source/$role.cfg" "$themeRoot/cursors/$role"
                      done

                      # Minecraft cursor packs use a vertical sprite sheet for busy.
                      # The importer already split it into frames and records the source
                      # timing as a plain text value to keep this derivation transparent.
                      IFS=, read -r xhot yhot < "$source/busy.hotspot"
                      : > "$source/busy.cfg"
                      for frame in "$source"/images/busy-*.png; do
                        printf '%s %s %s %s %s\n' 32 "$xhot" "$yhot" "images/$(basename "$frame")" 100 >> "$source/busy.cfg"
                      done
                      ${pkgs.xcursorgen}/bin/xcursorgen -p "$source" "$source/busy.cfg" "$themeRoot/cursors/watch"

                      # XCursor aliases are symlinks, not copied artwork. This covers
                      # names used by GTK, Qt, XWayland, and cursor-shape-v1 clients.
                      ${pkgs.lib.concatStringsSep "\n" (
                        builtins.concatLists (
                          pkgs.lib.mapAttrsToList (
                            role: aliases:
                            map (
                              alias: "if [ \"${alias}\" != \"${role}\" ]; then ln -s ${role} \"$themeRoot/cursors/${alias}\"; fi"
                            ) aliases
                          ) cursorAliases
                        )
                      )}

                      cat > "$themeRoot/index.theme" <<EOF
          [Icon Theme]
          Name=''${displayName}
          Comment=Pixel cursor theme
          EOF
                      mkdir -p "$TMPDIR/extract-$theme" "$TMPDIR/compile-$theme"
                      ${pkgs.hyprcursor}/bin/hyprcursor-util --extract "$themeRoot" --output "$TMPDIR/extract-$theme" --resize nearest
                      extracted="$TMPDIR/extract-$theme/extracted_$theme"
                      cat > "$extracted/manifest.hl" <<EOF
          name = ''${displayName}
          description = Pixel cursor theme
          version = 0.1
          cursors_directory = hyprcursors
          EOF
                      ${pkgs.hyprcursor}/bin/hyprcursor-util --create "$extracted" --output "$TMPDIR/compile-$theme"
                      compiled=$(find "$TMPDIR/compile-$theme" -mindepth 1 -maxdepth 1 -type d -print -quit)
                      cp -R "$compiled/hyprcursors/." "$themeRoot/hyprcursors/"
                      cp "$extracted/manifest.hl" "$themeRoot/manifest.hl"
                    done
                    runHook postInstall
        '';
      };
    };
}
