{ inputs, ... }:
let
  inherit (builtins) attrNames;
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
  };
in
{
  config.flake = {
    modules.darwin.default = {
      # nix-homebrew lets us declaratively control the installation of homebrew
      # with nix-homebrew.*
      # TODO: look into if we can use this to install under home-manager
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];
      homebrew.enable = true;
      homebrew.taps = attrNames taps;
      nix-homebrew = {
        inherit taps;
        enable = true;
        enableRosetta = true;
        user = "rafiq";
        mutableTaps = false;
      };
    };
  };
}
