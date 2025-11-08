{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins)
    mapAttrs
    any
    map
    attrValues
    ;
  inherit (lib.lists) optional uniqueStrings;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
  inherit (lib.types) enum;
  userBrowsers = pipe cfg.users.users [
    attrValues
    (map (x: x.apps.browser))
    uniqueStrings
  ];
in
{
  config.flake = {
    users.userOptions.apps.browser = mkOption { type = enum [ "firefox" ]; };
    allowedUnfreePackages = optional (any (x: x == "firefox") userBrowsers) "firefox-bin";
    modules.darwin = mapAttrs (
      _: userConfig:
      mkIf (userConfig.apps.browser == "firefox") {
        nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
      }
    ) cfg.users.users;
    modules.homeManager = mapAttrs (
      _: userConfig:
      (
        { pkgs, ... }:
        mkIf (userConfig.apps.browser == "firefox") {
          home.packages = [ pkgs.firefox-bin ];
          programs.firefox = {
            enable = true;
            package = if pkgs.stdenv.isDarwin then null else pkgs.firefox; # throws error on darwin
          };
        }
      )
    ) cfg.users.users;
  };
}
