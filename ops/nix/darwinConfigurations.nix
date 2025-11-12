{ inputs, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) attrNames;
in
{
  flake.darwinConfigurations.alpha = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      inputs.home-manager.darwinModules.home-manager
      inputs.nix-homebrew.darwinModules.nix-homebrew
      inputs.nix-rosetta-builder.darwinModules.default
      cfg.modules.darwin.leaf
    ];
  };
  flake.modules.darwin.leaf =
    let
      taps = {
        "homebrew/homebrew-core" = inputs.homebrew-core;
        "homebrew/homebrew-cask" = inputs.homebrew-cask;
      };
    in
    {
      nix.settings.experimental-features = "nix-command flakes";
      nixpkgs.hostPlatform = "aarch64-darwin";
      system = {
        configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
        stateVersion = 6;
        activationScripts.extraActivation.text = ''
          echo >&2 "ensuring rosetta is installed..."
          softwareupdate --install-rosetta --agree-to-license
          echo >&2 "configuring power management..."
          sudo pmset -a disablesleep 1
        '';
        defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
        keyboard.enableKeyMapping = true;
        keyboard.remapCapsLockToEscape = true;
      };
      homebrew.enable = true;
      homebrew.taps = attrNames taps;
      nix-homebrew = {
        inherit taps;
        enable = true;
        enableRosetta = true;
        user = cfg.users.admin.username;
        mutableTaps = false;
      };
      nix-rosetta-builder.onDemand = true;
    };
}
