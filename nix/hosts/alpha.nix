{
  inputs,
  config,
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
      cfg.modules.darwin.firefox
      cfg.modules.darwin.homebrew
      cfg.modules.darwin.yazi
      cfg.modules.darwin.rosetta-builder
      cfg.modules.darwin.darwin-system-defaults
      {
        imports = [
          inputs.sops-nix.darwinModules.sops
          inputs.mac-app-util.darwinModules.default
        ];
      }
      {
        networking.hostName = "alpha";
        nixpkgs = {
          hostPlatform = "aarch64-darwin";
        };
        system = {
          configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
          stateVersion = 6;
        };
        nix.settings = {
          extra-substituters = [
            "https://nix-community.cachix.org"
            "https://hyprland.cachix.org"
          ];
          extra-trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          ];
        };
        home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
        system.primaryUser = "rafiq";
      }
    ];
  };
}
