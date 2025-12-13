{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) attrNames;
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
  };
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf raw;
in
{
  options.flake.hosts.darwin = mkOption {
    type = attrsOf raw;
    default = { };
    description = "Attribute set where each member is a darwin host.";
  };
  config.flake.modules.darwin.default =
    { hostName, ... }:
    {
      networking.hostName = hostName;
      nixpkgs.hostPlatform = "aarch64-darwin";
      # nix-homebrew lets us declaratively control the installation of homebrew
      # with nix-homebrew.*
      # TODO: look into if we can use this to install under home-manager
      imports = [
        inputs.nix-homebrew.darwinModules.nix-homebrew
        # adds a linux builder that can build x86_64-linux with rosetta
        inputs.nix-rosetta-builder.darwinModules.default
      ];
      homebrew.enable = true;
      homebrew.taps = attrNames taps;
      nix-homebrew = {
        inherit taps;
        enable = true;
        enableRosetta = true;
        user = cfg.users.admin.username;
        mutableTaps = false;
      };
      nix.settings = {
        experimental-features = "nix-command flakes";
        extra-substituters = [ "https://nix-community.cachix.org" ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
      system.stateVersion = 6;
      nix-rosetta-builder.onDemand = true;
    };
}
