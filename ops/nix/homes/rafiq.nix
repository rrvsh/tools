{ inputs, lib, ... }:
{
  flake.modules.darwin.rafiq =
    { config, ... }:
    {
      nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "firefox-bin"
        ];
      system = {
        activationScripts = {
          extraActivation.text = lib.mkAfter config.system.activationScripts.pmset.text;
          pmset.text = ''
            echo >&2 "configuring power management..."
            sudo pmset -a disablesleep 1
          '';
        };
        defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
        keyboard.enableKeyMapping = true;
        keyboard.remapCapsLockToEscape = true;
      };
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
