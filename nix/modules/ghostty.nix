{
  config.flake = {
    modules.darwin.rafiq = {
      homebrew.casks = [ "ghostty" ];
    };
    modules.homeManager.rafiq =
      { lib, pkgs, ... }:
      {
        programs.ghostty = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty; # ghostty broken on darwin
          settings = lib.mkIf pkgs.stdenv.isLinux {
            keybind = [
              "cmd+t=new_tab"
              "cmd+w=close_surface"
              "cmd+shift+[=previous_tab"
              "cmd+shift+]=next_tab"
              "cmd+d=new_split:right"
              "cmd+shift+d=new_split:down"
              "cmd+alt+left=goto_split:left"
              "cmd+alt+right=goto_split:right"
              "cmd+alt+up=goto_split:up"
              "cmd+alt+down=goto_split:down"
              "cmd+c=copy_to_clipboard"
              "cmd+v=paste_from_clipboard"
              "alt+left=esc:b"
              "alt+right=esc:f"
              "alt+backspace=text:\\x17"
              "cmd+left=text:\\x01"
              "cmd+right=text:\\x05"
              "cmd+backspace=text:\\x15"
              "cmd+delete=esc:d"
            ];
          };
        };
      };
  };
}
