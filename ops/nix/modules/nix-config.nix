{ inputs, ... }:
let
  common.nix.settings = {
    experimental-features = "nix-command flakes";
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
in
{
  config.flake = {
    modules.nixos.leaf = common // {
      system.stateVersion = "25.11";
    };
    modules.darwin.leaf = common // {
      imports = [ inputs.nix-rosetta-builder.darwinModules.default ];
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
      system.stateVersion = 6;
      nix-rosetta-builder.onDemand = true;
    };
  };
}
