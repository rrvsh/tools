{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake.allowedUnfreePackages = [ "firefox-bin" ];
  config.flake.modules = {
    darwin.firefox = {
      nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
      home-manager.sharedModules = [ cfg.modules.homeManager.firefox ];
    };
    nixos.firefox = {
      home-manager.sharedModules = [ cfg.modules.homeManager.firefox ];
    };
    homeManager.firefox =
      { pkgs, ... }:
      {
        home.packages = lib.lists.optional pkgs.stdenv.isDarwin pkgs.firefox-bin;
        programs.firefox = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then null else pkgs.firefox;
        };
      };
  };
}
