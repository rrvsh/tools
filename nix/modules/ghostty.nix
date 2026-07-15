{ config, lib, ... }:
let
  cfg = config.flake;
  editorMimeTypes = [
    "application/toml"
    "application/x-shellscript"
    "application/x-yaml"
    "text/markdown"
    "text/plain"
    "text/x-c"
    "text/x-c++"
    "text/x-go"
    "text/x-java"
    "text/x-lua"
    "text/x-markdown"
    "text/x-nix"
    "text/x-python"
    "text/x-rust"
    "text/x-shellscript"
  ];
  defaultsFor =
    desktop: mimeTypes:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = [ desktop ];
      }) mimeTypes
    );
in
{
  config.flake.modules = {
    darwin.ghostty = {
      home-manager.sharedModules = [ cfg.modules.homeManager.ghostty ];
      homebrew.casks = [ "ghostty" ];
    };
    nixos.ghostty = {
      home-manager.sharedModules = [ cfg.modules.homeManager.ghostty ];
    };
    homeManager.ghostty =
      { pkgs, ... }:
      {
        programs.ghostty = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
        };
        xdg = lib.optionalAttrs pkgs.stdenv.isLinux {
          # Make text/code MIME handlers open files in Ghostty with the user's
          # runtime $EDITOR. A naive desktop Exec line that directly embeds
          # `ghostty -e sh -lc 'exec "$EDITOR" "$@"' ... %F` is fragile:
          # desktop-file validation requires `$` escaping inside quotes, while
          # over-escaping leaves the shell seeing literal `$@`/`$EDITOR` and the
          # Ghostty subcommand exits abnormally. Use a generated wrapper script
          # instead, and keep `%F` as normal desktop-file argument expansion.
          # `editor-shim` is the required argv[0] placeholder for `sh -c`; file
          # paths start after it so they are preserved in `$@`.
          desktopEntries.editor = {
            name = "Editor";
            exec = "${pkgs.writeShellScript "open-in-editor" ''
              exec ${pkgs.ghostty}/bin/ghostty -e ${pkgs.bash}/bin/sh -lc 'exec "''${EDITOR:-nvim}" "$@"' editor-shim "$@"
            ''} %F";
            noDisplay = true;
            mimeType = editorMimeTypes;
          };
          mimeApps = {
            enable = true;
            defaultApplications = defaultsFor "editor.desktop" editorMimeTypes;
          };
        };
      };
  };
}
