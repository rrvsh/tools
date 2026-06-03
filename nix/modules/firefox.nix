{ inputs, ... }:
{
  config.flake.modules.darwin.firefox =
    { lib, ... }:
    {
      nixpkgs = {
        config.allowUnfreePredicate = pkg: builtins.elem (lib.strings.getName pkg) [ "firefox-bin" ];
        overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
      };
    };
  config.flake.modules.homeManager.firefox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; lib.lists.optional stdenv.isDarwin firefox-bin;
      programs.firefox = {
        enable = true;
        package = if pkgs.stdenv.isDarwin then null else pkgs.firefox;
        # Keep explicit until home.stateVersion migration cleanup is complete.
        # Linux is on XDG path; old ~/.mozilla/firefox can be removed later.
        configPath =
          if pkgs.stdenv.isDarwin then
            "Library/Application Support/Firefox"
          else
            "${config.xdg.configHome}/mozilla/firefox";
      };
    };
}
