{
  lib,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins)
    mapAttrs
    ;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
in
{
  config.flake = {
    users.userOptions.apps.terminal = mkOption { type = enum [ "ghostty" ]; };
    modules.darwin = mapAttrs (
      _: userConfig:
      mkIf (userConfig.apps.terminal == "ghostty") {
        homebrew.casks = [ "ghostty" ];
      }
    ) cfg.users.users;
    modules.homeManager = mapAttrs (
      _: userConfig:
      (
        { pkgs, ... }:
        mkIf (userConfig.apps.terminal == "ghostty") {
          programs.ghostty = {
            enable = true;
            package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty; # ghostty broken on darwin
            clearDefaultKeybinds = true;
            settings.keybind = [
              "performable:super+c=copy_to_clipboard"
              "performable:super+v=paste_from_clipboard"
              "performable:super+t=new_tab"
            ];
          };
        }
      )
    ) cfg.users.users;
  };
}
