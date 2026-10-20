{ config, lib, ... }:
let
  cfg = config.flake.graphicalKeybinds;
  bindingType = lib.types.submodule {
    options = {
      modifiers = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "alt"
            "ctrl"
            "shift"
            "super"
          ]
        );
        default = [ ];
      };
      key = lib.mkOption { type = lib.types.str; };
    };
  };
  lua = lib.generators.mkLuaInline;
  hyprlandActions = {
    open-terminal.command = lua ''hl.dsp.exec_cmd("ghostty")'';
    open-browser.command = lua ''hl.dsp.exec_cmd("firefox")'';
    close-window.command = lua "hl.dsp.window.close()";
    toggle-floating.command = lua ''hl.dsp.window.float({ action = "toggle" })'';
    toggle-fullscreen.command = lua "hl.dsp.window.fullscreen()";
    focus-left.command = lua ''hl.dsp.focus({ direction = "left" })'';
    focus-down.command = lua ''hl.dsp.focus({ direction = "down" })'';
    focus-up.command = lua ''hl.dsp.focus({ direction = "up" })'';
    focus-right.command = lua ''hl.dsp.focus({ direction = "right" })'';
    move-left.command = lua ''hl.dsp.window.move({ direction = "left" })'';
    move-down.command = lua ''hl.dsp.window.move({ direction = "down" })'';
    move-up.command = lua ''hl.dsp.window.move({ direction = "up" })'';
    move-right.command = lua ''hl.dsp.window.move({ direction = "right" })'';
    workspace-previous.command = lua ''hl.dsp.focus({ workspace = "r-1" })'';
    workspace-next.command = lua ''hl.dsp.focus({ workspace = "r+1" })'';
    move-workspace-previous.command = lua ''hl.dsp.window.move({ workspace = "r-1" })'';
    move-workspace-next.command = lua ''hl.dsp.window.move({ workspace = "r+1" })'';
    open-launcher.command = lua ''hl.dsp.exec_cmd("wofi --show drun")'';
    volume-up = {
      command = lua ''hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+")'';
      options.repeating = true;
    };
    volume-down = {
      command = lua ''hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-")'';
      options.repeating = true;
    };
    mute-output.command = lua ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")'';
    mute-input.command = lua ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")'';
    drag-window = {
      command = lua "hl.dsp.window.drag()";
      options.mouse = true;
    };
    resize-window = {
      command = lua "hl.dsp.window.resize()";
      options.mouse = true;
    };
  };
  aerospaceActions = {
    open-terminal = "exec-and-forget osascript -e 'tell application \"Ghostty\" to new window'";
    open-browser = "exec-and-forget open -a Firefox";
    close-window = "close";
    toggle-floating = "layout floating tiling";
    toggle-fullscreen = "fullscreen";
    focus-left = "focus left";
    focus-down = "focus down";
    focus-up = "focus up";
    focus-right = "focus right";
    move-left = "move left";
    move-down = "move down";
    move-up = "move up";
    move-right = "move right";
    workspace-previous = "workspace prev";
    workspace-next = "workspace next";
    move-workspace-previous = "move-node-to-workspace --focus-follows-window prev";
    move-workspace-next = "move-node-to-workspace --focus-follows-window next";
  };
in
{
  options.flake.graphicalKeybinds = lib.mkOption {
    type = lib.types.submodule {
      options = {
        shared = lib.mkOption {
          type = lib.types.attrsOf bindingType;
          default = { };
        };
        hyprlandOverrides = lib.mkOption {
          type = lib.types.attrsOf bindingType;
          default = { };
        };
        aerospaceOverrides = lib.mkOption {
          type = lib.types.attrsOf bindingType;
          default = { };
        };
      };
    };
    default = { };
  };
  config.flake.modules = {
    nixos.graphicalKeybinds = {
      home-manager.sharedModules = [
        ({ config, ... }: {
          config = lib.mkIf config.wayland.windowManager.hyprland.enable {
            wayland.windowManager.hyprland.settings.bind = lib.mapAttrsToList (
              action: binding:
              let
                translation = hyprlandActions.${action};
              in
              {
                _args = [
                  (lib.concatStringsSep " + " (
                    map lib.toUpper (
                      lib.filter (modifier: builtins.elem modifier binding.modifiers) [
                        "alt"
                        "ctrl"
                        "shift"
                        "super"
                      ]
                    )
                    ++ [ binding.key ]
                  ))
                  translation.command
                ]
                ++ lib.optional (translation ? options) translation.options;
              }
            ) (cfg.shared // cfg.hyprlandOverrides);
          };
        })
      ];
    };
    darwin.graphicalKeybinds = {
      home-manager.sharedModules = [
        ({ config, ... }: {
          config = lib.mkIf config.programs.aerospace.enable {
            programs.aerospace.settings.mode.main.binding = builtins.listToAttrs (
              lib.mapAttrsToList (action: binding: {
                name = lib.concatStringsSep "-" (
                  map (modifier: if modifier == "super" then "cmd" else modifier) (
                    lib.filter (modifier: builtins.elem modifier binding.modifiers) [
                      "super"
                      "alt"
                      "ctrl"
                      "shift"
                    ]
                  )
                  ++ [ (lib.toLower binding.key) ]
                );
                value = aerospaceActions.${action};
              }) (cfg.shared // cfg.aerospaceOverrides)
            );
          };
        })
      ];
    };
  };
}
