{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
in
{
  config.flake = {
    users.userOptions.apps.file-browser = mkOption { type = enum [ "yazi" ]; };
    modules.darwin = mapAttrs (
      _: userConfig:
      mkIf (userConfig.apps.file-browser == "yazi") {
        nix.settings.extra-substituters = [ "https://yazi.cachix.org" ];
        nix.settings.extra-trusted-public-keys = [
          "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        ];
      }
    ) cfg.users.users;
    modules.homeManager = mapAttrs (
      _: userConfig:
      (
        { pkgs, ... }:
        mkIf (userConfig.apps.file-browser == "yazi") {
          programs.yazi = {
            enable = true;
            package = inputs.yazi.packages.${pkgs.system}.default.override {
              # this will use the binary cache configured above
              # but only after it is registered i.e. after a system rebuild is done with the above and **without this**
              # so comment this package out the first time you rebuild, then uncomment it and rebuild again
              runtimeDeps = ps: ps ++ [ pkgs.exiftool ];
            };
          };
        }
      )
    ) cfg.users.users;
  };
}
