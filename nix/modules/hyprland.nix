{ inputs, ... }:
{
  config.flake.modules.nixos.hyprland =
    { config, pkgs, ... }:
    {
      imports = [ inputs.hyprland.nixosModules.default ];
      nix.settings = {
        extra-substituters = [ "https://hyprland.cachix.org" ];
        extra-trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
      };
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
      assertions = [
        {
          assertion = config.networking.hostName != "";
          message = "Hyprland module expects a hostName.";
        }
      ];
      xdg.portal = {
        enable = true;
        extraPortals = [ config.programs.hyprland.portalPackage ];
      };
    };
  config.flake.modules.homeManager.hyprland =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    lib.mkIf pkgs.stdenv.isLinux {
      wayland.windowManager.hyprland = {
        enable = osConfig.programs.hyprland.enable or false;
        configType = "lua";
        package = null;
        portalPackage = null;
        extraConfig = ''
          hl.on("hyprland.start", function()
            hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user restart waybar.service waybar-peek.service")
          end)
        '';
        settings = {
          monitor = [
            {
              output = "HDMI-A-1";
              mode = "3840x2160@160";
              position = "auto";
              scale = 2;
            }
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = 2;
            }
          ];
          config = {
            input.sensitivity = 1.0;
            general = {
              gaps_in = 0;
              gaps_out = 0;
              border_size = 0;
            };
          };
          bind = [
            {
              _args = [
                "XF86AudioRaiseVolume"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+\")")
                { repeating = true; }
              ];
            }
            {
              _args = [
                "XF86AudioLowerVolume"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-\")")
                { repeating = true; }
              ];
            }
            {
              _args = [
                "XF86AudioMute"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\")")
              ];
            }
            {
              _args = [
                "XF86AudioMicMute"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\")")
              ];
            }
            {
              _args = [
                "ALT + SPACE"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wofi --show drun\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + 1"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"ghostty\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + 2"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"firefox\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + W"
                (lib.generators.mkLuaInline "hl.dsp.window.close()")
              ];
            }
            {
              _args = [
                "ALT + CTRL + P"
                (lib.generators.mkLuaInline "hl.dsp.window.float({ action = \"toggle\" })")
              ];
            }
            {
              _args = [
                "ALT + H"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"left\" })")
              ];
            }
            {
              _args = [
                "ALT + J"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"down\" })")
              ];
            }
            {
              _args = [
                "ALT + K"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"up\" })")
              ];
            }
            {
              _args = [
                "ALT + L"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"right\" })")
              ];
            }
            {
              _args = [
                "ALT + SUPER + H"
                (lib.generators.mkLuaInline "hl.dsp.focus({ workspace = \"r-1\" })")
              ];
            }
            {
              _args = [
                "ALT + SUPER + L"
                (lib.generators.mkLuaInline "hl.dsp.focus({ workspace = \"r+1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + H"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"left\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + J"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"down\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + K"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"up\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + L"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"right\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + SUPER + H"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { workspace = \"r-1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + SUPER + L"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { workspace = \"r+1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + mouse:272"
                (lib.generators.mkLuaInline "hl.dsp.window.drag()")
                { mouse = true; }
              ];
            }
            {
              _args = [
                "ALT + SHIFT + mouse:273"
                (lib.generators.mkLuaInline "hl.dsp.window.resize()")
                { mouse = true; }
              ];
            }
          ];
        };
      };
      services.hypridle = lib.mkIf (osConfig.programs.hyprland.enable or false) (
        let
          uid = toString osConfig.users.users.rafiq.uid;
          runtimeDir = "/run/user/${uid}";
          idleStateFile = "${runtimeDir}/hypridle-state";
        in
        {
          enable = true;
          settings.listener = [
            {
              timeout = 60;
              on-timeout = "${pkgs.bash}/bin/bash -lc 'printf idle > \"${idleStateFile}\"'";
              on-resume = "${pkgs.bash}/bin/bash -lc 'printf active > \"${idleStateFile}\"'";
            }
          ];
        }
      );
      assertions = [
        {
          assertion =
            osConfig.programs.hyprland.portalPackage
            == inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
          message = "You must be using xdg-desktop-portal-hyprland for Pipewire screencapturing to work.";
        }
        {
          assertion = osConfig.services.pipewire.enable && osConfig.services.pipewire.wireplumber.enable;
          message = "You must enable pipewire and wireplumber for screencapturing to work.";
        }
      ];
    };
}
