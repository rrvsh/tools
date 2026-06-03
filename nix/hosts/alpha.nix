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
  config.flake.darwinConfigurations.alpha = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      cfg.modules.darwin.rafiq
      cfg.modules.darwin.passwordless-sudo
      cfg.modules.darwin.nix-settings
      cfg.modules.darwin.ssh-config
      cfg.modules.darwin.tailscale-config
      {
        imports = [
          inputs.sops-nix.darwinModules.sops
          inputs.nix-homebrew.darwinModules.nix-homebrew
          inputs.nix-rosetta-builder.darwinModules.default
          inputs.mac-app-util.darwinModules.default
        ];
      }
      {
        networking.hostName = "alpha";
        nixpkgs = {
          hostPlatform = "aarch64-darwin";
          config.allowUnfreePredicate = pkg: builtins.elem (lib.strings.getName pkg) [ "firefox-bin" ];
          overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
        };
        system = {
          configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
          stateVersion = 6;
        };
        nix.settings = {
          extra-substituters = [
            "https://nix-community.cachix.org"
            "https://hyprland.cachix.org"
            "https://yazi.cachix.org"
          ];
          extra-trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
          ];
        };
        nix-rosetta-builder.onDemand = true;
        homebrew = {
          enable = true;
          taps = builtins.attrNames {
            "homebrew/homebrew-core" = inputs.homebrew-core;
            "homebrew/homebrew-cask" = inputs.homebrew-cask;
          };
          brews = [ "docker" ];
        };
        nix-homebrew = {
          taps = {
            "homebrew/homebrew-core" = inputs.homebrew-core;
            "homebrew/homebrew-cask" = inputs.homebrew-cask;
          };
          enable = true;
          enableRosetta = true;
          mutableTaps = false;
          user = "rafiq";
        };
        home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
        system = {
          primaryUser = "rafiq";
          activationScripts.extraActivation.text = lib.mkMerge [
            (lib.mkBefore ''
              echo >&2 "ensuring rosetta is installed..."
              softwareupdate --install-rosetta --agree-to-license
            '')
            ''
              echo >&2 "disabling sleep..."
              sudo pmset -a disablesleep 1
              echo >&2 "disabling display sleep..."
              sudo pmset -a displaysleep 0
            ''
          ];
          defaults.NSGlobalDomain = {
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
