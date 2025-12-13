{ inputs, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) attrNames;
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
  };
in
{
  flake.modules.darwin.default = {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];
    homebrew.enable = true;
    homebrew.taps = attrNames taps;
    nix-homebrew = {
      inherit taps;
      enable = true;
      enableRosetta = true;
      user = cfg.users.admin.username;
      mutableTaps = false;
    };
  };
}
