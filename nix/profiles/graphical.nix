{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake = {
    graphicalKeybinds = {
      shared = {
        open-terminal = {
          modifiers = [
            "alt"
            "ctrl"
          ];
          key = "1";
        };
        open-browser = {
          modifiers = [
            "alt"
            "ctrl"
          ];
          key = "2";
        };
        screenshot-region = {
          modifiers = [
            "alt"
            "ctrl"
          ];
          key = "S";
        };
        close-window = {
          modifiers = [
            "alt"
            "ctrl"
          ];
          key = "W";
        };
        toggle-floating = {
          modifiers = [
            "alt"
            "ctrl"
          ];
          key = "P";
        };
        toggle-fullscreen = {
          modifiers = [
            "alt"
            "ctrl"
          ];
          key = "F";
        };
        focus-left = {
          modifiers = [ "alt" ];
          key = "H";
        };
        focus-down = {
          modifiers = [ "alt" ];
          key = "J";
        };
        focus-up = {
          modifiers = [ "alt" ];
          key = "K";
        };
        focus-right = {
          modifiers = [ "alt" ];
          key = "L";
        };
        move-left = {
          modifiers = [
            "alt"
            "shift"
          ];
          key = "H";
        };
        move-down = {
          modifiers = [
            "alt"
            "shift"
          ];
          key = "J";
        };
        move-up = {
          modifiers = [
            "alt"
            "shift"
          ];
          key = "K";
        };
        move-right = {
          modifiers = [
            "alt"
            "shift"
          ];
          key = "L";
        };
        workspace-previous = {
          modifiers = [
            "alt"
            "super"
          ];
          key = "H";
        };
        workspace-next = {
          modifiers = [
            "alt"
            "super"
          ];
          key = "L";
        };
        move-workspace-previous = {
          modifiers = [
            "alt"
            "shift"
            "super"
          ];
          key = "H";
        };
        move-workspace-next = {
          modifiers = [
            "alt"
            "shift"
            "super"
          ];
          key = "L";
        };
      };
      hyprlandOverrides = {
        open-launcher = {
          modifiers = [ "alt" ];
          key = "SPACE";
        };
        volume-up.key = "XF86AudioRaiseVolume";
        volume-down.key = "XF86AudioLowerVolume";
        mute-output.key = "XF86AudioMute";
        mute-input.key = "XF86AudioMicMute";
        drag-window = {
          modifiers = [
            "alt"
            "shift"
          ];
          key = "mouse:272";
        };
        resize-window = {
          modifiers = [
            "alt"
            "shift"
          ];
          key = "mouse:273";
        };
      };
      applications.ghostty = {
        split-right = {
          modifiers = [ "super" ];
          key = "D";
        };
        focus-split-left = {
          modifiers = [
            "ctrl"
            "alt"
          ];
          key = "H";
        };
        focus-split-down = {
          modifiers = [
            "ctrl"
            "alt"
          ];
          key = "J";
        };
        focus-split-up = {
          modifiers = [
            "ctrl"
            "alt"
          ];
          key = "K";
        };
        focus-split-right = {
          modifiers = [
            "ctrl"
            "alt"
          ];
          key = "L";
        };
      };
    };
    modules.darwin.profile-graphical =
      { pkgs, ... }:
      {
        imports = with cfg.modules.darwin; [
          graphicalKeybinds
          firefox
          ghostty
          inputs.mac-app-util.darwinModules.default
        ];
        system = {
          activationScripts.extraActivation.text = ''
            echo >&2 "disabling sleep..."
            sudo pmset -a disablesleep 1
            echo >&2 "disabling display sleep..."
            sudo pmset -a displaysleep 0
          '';
          defaults = {
            dock.autohide = true;
            NSGlobalDomain = {
              _HIHideMenuBar = true;
              "com.apple.swipescrolldirection" = false;
            };
          };
          keyboard = {
            enableKeyMapping = true;
            remapCapsLockToEscape = true;
          };
        };
        homebrew.casks = [
          "mixxx"
          "linearmouse"
          "spotify"
        ];
        home-manager.sharedModules = [
          inputs.mac-app-util.homeManagerModules.default
          {
            home.packages = with pkgs; [
              alt-tab-macos
              monitorcontrol
            ];
            # mac-app-util needs the linked app directory to create Spotlight-indexed trampolines.
            targets.darwin.copyApps.enable = lib.mkForce false;
            targets.darwin.linkApps.enable = true;
          }
        ];
      };
    modules.nixos.profile-graphical =
      {
        config,
        lib,
        pkgs,
        primaryUser,
        ...
      }:
      {
        imports = with cfg.modules.nixos; [
          graphicalKeybinds
          quickshell
          wofi
          ghostty
          firefox
          hyprland
          audio-config
          cursor-themes
          greetd-tuigreet
          removable-media
        ];
        services.tuigreet = {
          enable = true;
          settings = {
            # Keep Hyprland startup output off tty1 while retaining it in the journal.
            session.command = "${pkgs.writeShellScript "start-hyprland-session" ''
              exec ${config.programs.hyprland.package}/bin/start-hyprland \
                > >(${lib.getExe' pkgs.systemd "systemd-cat"} --identifier=start-hyprland) 2>&1
            ''}";
            layout.widgets.status_bar = {
              show_reset = false;
              show_command = false;
              show_session = false;
              show_power = false;
              show_background = false;
              show_session_status = false;
              show_caps_lock = false;
            };
            remember = {
              default_user = primaryUser.name;
              username = true;
            };
          };
        };
        time.timeZone = "Asia/Singapore";
        security.polkit.enable = true;
        programs.dconf.enable = true;
        hardware.i2c.enable = true; # ddc
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              mixxx
              libnotify
              grim
              slurp
              wl-clipboard
              activitywatch
              aw-watcher-window-wayland
            ];
            services = {
              hypridle.enable = true;
              dunst.enable = true;
              activitywatch = {
                enable = true;
                package = pkgs.activitywatch;
                watchers.aw-watcher-window-wayland = {
                  package = pkgs.aw-watcher-window-wayland;
                };
              };
            };
            systemd.user.services.activitywatch-watcher-aw-watcher-window-wayland.Service = {
              Restart = "on-failure";
              RestartSec = 5;
            };
          }
        ];
      };
  };
}
