{ inputs, ... }:
{
  config.flake = {
    modules.darwin.default = {
      nixpkgs.hostPlatform = "aarch64-darwin";
      nix.settings = {
        trusted-users = [ "rafiq" ];
        experimental-features = "nix-command flakes";
        extra-substituters = [ "https://nix-community.cachix.org" ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
      system.stateVersion = 6;
    };
  };
}
