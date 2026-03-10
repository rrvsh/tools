{ inputs, ... }:
let
  inherit (builtins) attrNames;
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
  };
in
{
  config.flake.modules.darwin.homebrew = {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];
    homebrew.enable = true;
    homebrew.taps = attrNames taps;
    nix-homebrew = {
      inherit taps;
      enable = true;
      enableRosetta = true;
      mutableTaps = false;
    };
  };
}
