{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  browserMimeTypes = [
    "application/atom+xml"
    "application/json"
    "application/ld+json"
    "application/pdf"
    "application/rss+xml"
    "application/vnd.mozilla.xul+xml"
    "application/xhtml+xml"
    "application/xml"
    "audio/flac"
    "audio/mpeg"
    "audio/ogg"
    "audio/wav"
    "audio/webm"
    "image/avif"
    "image/gif"
    "image/jpeg"
    "image/png"
    "image/svg+xml"
    "image/webp"
    "text/html"
    "text/xml"
    "video/mp4"
    "video/ogg"
    "video/webm"
    "video/x-matroska"
    "x-scheme-handler/about"
    "x-scheme-handler/ftp"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/webcal"
  ];
  defaultsFor =
    desktop: mimeTypes:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = [ desktop ];
      }) mimeTypes
    );
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
        xdg = lib.optionalAttrs pkgs.stdenv.isLinux {
          mimeApps = {
            enable = true;
            defaultApplications = defaultsFor "firefox.desktop" browserMimeTypes;
          };
        };
      };
  };
}
