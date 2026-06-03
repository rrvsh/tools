{ inputs, ... }:
{
  config.flake = {
    allowedUnfreePackages = [ "firefox-bin" ];
    modules.darwin.firefox = {
      nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
    };
    modules.homeManager.firefox =
      {
        lib,
        pkgs,
        ...
      }:
      {
        home.packages = with pkgs; lib.lists.optional stdenv.isDarwin firefox-bin;
        programs.firefox = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then null else pkgs.firefox;
        };
      };
  };
}
