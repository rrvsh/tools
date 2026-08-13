{
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.flake;
  lua = lib.generators.mkLuaInline;
  mkBind = key: command: {
    _args = [
      key
      (lua command)
    ];
  };
  hjklDirections = [
    {
      key = "H";
      direction = "left";
    }
    {
      key = "J";
      direction = "down";
    }
    {
      key = "K";
      direction = "up";
    }
    {
      key = "L";
      direction = "right";
    }
  ];
  mkHjklBinds =
    modifier: action:
    builtins.map (
      { key, direction }: mkBind "${modifier} + ${key}" "${action}({ direction = \"${direction}\" })"
    ) hjklDirections;
in
{
  config.flake.modules.nixos.hyprland =
    { config, pkgs, ... }:
    {
      imports = [ inputs.hyprland.nixosModules.default ];
      home-manager.sharedModules = [ cfg.modules.homeManager.hyprland ];
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
      xdg.portal = {
        enable = true;
        extraPortals = [ config.programs.hyprland.portalPackage ];
      };
    };
  config.flake.modules.homeManager.hyprland =
    { pkgs, ... }:
    {
      wayland.windowManager.hyprland = {
        enable = true;
        configType = "lua";
        package = null;
        portalPackage = null;
        plugins = [
          inputs.hypr-dynamic-cursors.packages.${pkgs.stdenv.hostPlatform.system}.hypr-dynamic-cursors
        ];
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
            plugin.dynamic_cursors = {
              mode = "tilt";
              tilt = {
                limit = 3000;
                activation = "linear";
                window = 80;
                full = 25;
              };
              shake = {
                enabled = true;
                threshold = 3.0;
                base = 3.0;
                speed = 0;
                timeout = 500;
                effects = true;
              };
            };
          };
          bind = [
            {
              _args = [
                "XF86AudioRaiseVolume"
                (lua "hl.dsp.exec_cmd(\"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+\")")
                { repeating = true; }
              ];
            }
            {
              _args = [
                "XF86AudioLowerVolume"
                (lua "hl.dsp.exec_cmd(\"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-\")")
                { repeating = true; }
              ];
            }
            {
              _args = [
                "XF86AudioMute"
                (lua "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\")")
              ];
            }
            {
              _args = [
                "XF86AudioMicMute"
                (lua "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\")")
              ];
            }
            {
              _args = [
                "ALT + SPACE"
                (lua "hl.dsp.exec_cmd(\"wofi --show drun\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + 1"
                (lua "hl.dsp.exec_cmd(\"ghostty\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + 2"
                (lua "hl.dsp.exec_cmd(\"firefox\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + W"
                (lua "hl.dsp.window.close()")
              ];
            }
            {
              _args = [
                "ALT + CTRL + P"
                (lua "hl.dsp.window.float({ action = \"toggle\" })")
              ];
            }
          ]
          ++ mkHjklBinds "ALT" "hl.dsp.focus"
          ++ [
            {
              _args = [
                "ALT + SUPER + H"
                (lua "hl.dsp.focus({ workspace = \"r-1\" })")
              ];
            }
            {
              _args = [
                "ALT + SUPER + L"
                (lua "hl.dsp.focus({ workspace = \"r+1\" })")
              ];
            }
          ]
          ++ mkHjklBinds "ALT + SHIFT" "hl.dsp.window.move"
          ++ [
            {
              _args = [
                "ALT + SHIFT + SUPER + H"
                (lua "hl.dsp.window.move( { workspace = \"r-1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + SUPER + L"
                (lua "hl.dsp.window.move( { workspace = \"r+1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + mouse:272"
                (lua "hl.dsp.window.drag()")
                { mouse = true; }
              ];
            }
            {
              _args = [
                "ALT + SHIFT + mouse:273"
                (lua "hl.dsp.window.resize()")
                { mouse = true; }
              ];
            }
          ];
        };
      };
    };
}
