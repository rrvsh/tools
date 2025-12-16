{ inputs, lib, ... }:
{
  config.flake = {
    allowedUnfreePackages = [ "firefox-bin" ];
    # macOS upstream Firefox in nixpkgs is broken; this overlay provides the working firefox-bin build for Darwin.
    modules.darwin.rafiq = {
      nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
    };
    modules.homeManager.rafiq =
      { pkgs, ... }:
      {
        home.packages = lib.lists.optional pkgs.stdenv.isDarwin pkgs.firefox-bin;
        programs.firefox = {
          enable = true;
          # HM’s firefox module errors on Darwin when a package is set; keep null on macOS and install via home.packages.
          package = if pkgs.stdenv.isDarwin then null else pkgs.firefox;
        };
      };
  };
}
