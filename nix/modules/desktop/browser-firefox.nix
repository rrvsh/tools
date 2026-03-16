{ inputs, lib, ... }:
{
  config.flake = {
    allowedUnfreePackages = [ "firefox-bin" ];
    modules.darwin.rafiq = {
      nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
    };
    modules.homeManager.rafiq =
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
