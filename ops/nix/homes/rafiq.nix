{ inputs, lib, ... }:
{
  flake.modules.darwin.rafiq = {
    nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "firefox-bin"
      ];
    system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
  };
  flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      home.packages = with pkgs; [
        neovim
        gh
        firefox-bin
      ];
      programs.firefox = {
        enable = true;
        package = null;
      };
    };
}
