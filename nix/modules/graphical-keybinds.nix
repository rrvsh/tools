{ config, lib, ... }:
let
  cfg = config.flake;
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
  hyprlandActions = {
    open-terminal.command = lib.generators.mkLuaInline ''hl.dsp.exec_cmd("ghostty")'';
    open-browser.command = lib.generators.mkLuaInline ''hl.dsp.exec_cmd("firefox")'';
    close-window.command = lib.generators.mkLuaInline "hl.dsp.window.close()";
    toggle-floating.command = lib.generators.mkLuaInline ''hl.dsp.window.float({ action = "toggle" })'';
    toggle-fullscreen.command = lib.generators.mkLuaInline "hl.dsp.window.fullscreen()";
    focus-left.command = lib.generators.mkLuaInline ''hl.dsp.focus({ direction = "left" })'';
    focus-down.command = lib.generators.mkLuaInline ''hl.dsp.focus({ direction = "down" })'';
    focus-up.command = lib.generators.mkLuaInline ''hl.dsp.focus({ direction = "up" })'';
    focus-right.command = lib.generators.mkLuaInline ''hl.dsp.focus({ direction = "right" })'';
    move-left.command = lib.generators.mkLuaInline ''hl.dsp.window.move({ direction = "left" })'';
    move-down.command = lib.generators.mkLuaInline ''hl.dsp.window.move({ direction = "down" })'';
    move-up.command = lib.generators.mkLuaInline ''hl.dsp.window.move({ direction = "up" })'';
    move-right.command = lib.generators.mkLuaInline ''hl.dsp.window.move({ direction = "right" })'';
    workspace-previous.command = lib.generators.mkLuaInline ''hl.dsp.focus({ workspace = "r-1" })'';
    workspace-next.command = lib.generators.mkLuaInline ''hl.dsp.focus({ workspace = "r+1" })'';
    move-workspace-previous.command = lib.generators.mkLuaInline ''hl.dsp.window.move({ workspace = "r-1" })'';
    move-workspace-next.command = lib.generators.mkLuaInline ''hl.dsp.window.move({ workspace = "r+1" })'';
    open-launcher.command = lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wofi --show drun")'';
    volume-up = {
      command = lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+")'';
      options.repeating = true;
    };
    volume-down = {
      command = lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-")'';
      options.repeating = true;
    };
    mute-output.command = lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")'';
    mute-input.command = lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")'';
    drag-window = {
      command = lib.generators.mkLuaInline "hl.dsp.window.drag()";
      options.mouse = true;
    };
    resize-window = {
      command = lib.generators.mkLuaInline "hl.dsp.window.resize()";
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
            ) (cfg.graphicalKeybinds.shared // cfg.graphicalKeybinds.hyprlandOverrides);
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
              }) (cfg.graphicalKeybinds.shared // cfg.graphicalKeybinds.aerospaceOverrides)
            );
          };
        })
      ];
    };
  };
}
