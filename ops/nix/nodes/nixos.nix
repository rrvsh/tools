{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib) nixosSystem;
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf raw;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  options.flake.nodes.nixos = mkOption { type = attrsOf raw; };
  config.flake.nixosConfigurations = mapAttrs (
    name: value:
    nixosSystem {
      specialArgs = {
        hostName = name;
        hostConfig = value;
      };
      modules = [ cfg.modules.nixos.default ];
    }
  ) cfg.nodes.nixos;
  config.flake.modules.nixos.default = {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [ "https://nix-community.cachix.org" ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-substituters = [ "https://nix-community.cachix.org" ];
    };
    system.stateVersion = "25.11";
  };
}
