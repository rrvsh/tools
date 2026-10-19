{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.aerospace = {
      home-manager.sharedModules = [ cfg.modules.homeManager.aerospace ];
    };
    homeManager.aerospace = {
      programs.aerospace = {
        enable = true;
        launchd.enable = true;
        settings = {
          config-version = 2;
          persistent-workspaces = [
            "1"
            "2"
            "3"
            "4"
            "5"
            "6"
            "7"
            "8"
            "9"
          ];
          mode.main.binding = {
            alt-h = "focus left";
            alt-j = "focus down";
            alt-k = "focus up";
            alt-l = "focus right";
            alt-shift-h = "move left";
            alt-shift-j = "move down";
            alt-shift-k = "move up";
            alt-shift-l = "move right";
            cmd-alt-h = "workspace prev";
            cmd-alt-l = "workspace next";
            cmd-alt-shift-h = "move-node-to-workspace --focus-follows-window prev";
            cmd-alt-shift-l = "move-node-to-workspace --focus-follows-window next";
          };
        };
      };
    };
  };
}
