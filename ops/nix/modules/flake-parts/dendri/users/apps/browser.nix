{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs any;
  inherit (lib.lists) optional;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
  inherit (lib.attrsets) mapAttrsToList;
  userBrowsers = mapAttrsToList (_: value: value.apps.browser) cfg.users.users;
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
