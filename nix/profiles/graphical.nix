{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake.modules.darwin.profile-graphical =
    { pkgs, ... }:
    {
      imports = with cfg.modules.darwin; [
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
        defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
        keyboard = {
          enableKeyMapping = true;
          remapCapsLockToEscape = true;
        };
      };
      homebrew.casks = [ "mixxx" ];
      home-manager.sharedModules = [
        inputs.mac-app-util.homeManagerModules.default
        {
          home.packages = with pkgs; [
            alt-tab-macos
            monitorcontrol
          ];
          targets.darwin.copyApps.enable = lib.mkForce false;
        }
      ];
    };
  config.flake.modules.nixos.profile-graphical =
    { pkgs, ... }:
    {
      imports = with cfg.modules.nixos; [
        waybar
        wofi
        ghostty
        firefox
        hyprland
        audio-config
      ];
      time.timeZone = "Asia/Singapore";
      security.polkit.enable = true;
      programs.dconf.enable = true;
      hardware.i2c.enable = true; # ddc
      home-manager.sharedModules = [
        {
          home.packages = with pkgs; [
            mixxx
            libnotify
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
}
