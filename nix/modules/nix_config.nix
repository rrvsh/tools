{ inputs, ... }:
{
  config.flake = {
    modules.nixos.default = {
      nix.settings = {
        trusted-users = [ "rafiq" ];
        experimental-features = "nix-command flakes";
        extra-substituters = [
          "https://nix-community.cachix.org"
          "https://hyprland.cachix.org"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
      };
    };
    modules.darwin.default = {
      nixpkgs.hostPlatform = "aarch64-darwin";
      nix.settings = {
        trusted-users = [ "rafiq" ];
        experimental-features = "nix-command flakes";
        extra-substituters = [
          "https://nix-community.cachix.org"
          "https://hyprland.cachix.org"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
      };
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
      system.stateVersion = 6;
    };
  };
}
