{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.aerospace =
      {
        config,
        lib,
        ...
      }:
      let
        user = config.system.primaryUser;
        userHome = config.users.users.${user}.home;
      in
      {
        home-manager.sharedModules = [ cfg.modules.homeManager.aerospace ];
        system = {
          activationScripts.postActivation.text = lib.mkAfter ''
            shortcutDir=$(/usr/bin/mktemp -d)
            shortcutPlist="$shortcutDir/symbolichotkeys.plist"
            /bin/chmod 755 "$shortcutDir"
            /usr/bin/sudo -u ${lib.escapeShellArg user} /usr/bin/env HOME=${lib.escapeShellArg userHome} \
              /usr/bin/defaults export com.apple.symbolichotkeys "$shortcutPlist"
            if ! /usr/bin/plutil -extract AppleSymbolicHotKeys raw "$shortcutPlist" >/dev/null 2>&1; then
              /usr/bin/plutil -insert AppleSymbolicHotKeys -dictionary "$shortcutPlist"
            fi
            for shortcut in 32 79 80 81 82; do
              if /usr/bin/plutil -extract "AppleSymbolicHotKeys.$shortcut" raw "$shortcutPlist" >/dev/null 2>&1; then
                /usr/bin/plutil -replace "AppleSymbolicHotKeys.$shortcut.enabled" -bool false "$shortcutPlist"
              else
                /usr/bin/plutil -insert "AppleSymbolicHotKeys.$shortcut" -json '{"enabled":false}' "$shortcutPlist"
              fi
            done
            /usr/bin/sudo -u ${lib.escapeShellArg user} /usr/bin/env HOME=${lib.escapeShellArg userHome} \
              /usr/bin/defaults import com.apple.symbolichotkeys "$shortcutPlist"
            /bin/rm -rf "$shortcutDir"
          '';
          defaults = {
            WindowManager.GloballyEnabled = false;
            dock = {
              mru-spaces = false;
              showAppExposeGestureEnabled = false;
              showMissionControlGestureEnabled = false;
            };
            spaces.spans-displays = true;
            trackpad = {
              TrackpadFourFingerHorizSwipeGesture = 0;
              TrackpadFourFingerVertSwipeGesture = 0;
              TrackpadThreeFingerHorizSwipeGesture = 0;
              TrackpadThreeFingerVertSwipeGesture = 0;
            };
          };
        };
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
