{ inputs, config, ... }:
let
  cfg = config.flake;
  inherit (inputs.nix-darwin.lib) darwinSystem;
in
{
  config.flake.darwinConfigurations.alpha = darwinSystem {
    modules = [
      cfg.modules.darwin.default
      cfg.modules.darwin.rafiq
      {
        networking.hostName = "alpha";
        system = {
          activationScripts.extraActivation.text = ''
            echo >&2 "disabling sleep..."
            sudo pmset -a disablesleep 1
            echo >&2 "disabling display sleep..."
            sudo pmset -a displaysleep 0
          '';
          defaults.NSGlobalDomain = {
            # disable natural (touchscreen) scrolling
            # swipe up -> scroll up
            "com.apple.swipescrolldirection" = false;
          };
          keyboard = {
            enableKeyMapping = true;
            remapCapsLockToEscape = true;
          };
        };
      }
    ];
  };
}
