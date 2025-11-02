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
  inherit (lib.types) attrsOf;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  options.flake.nodes.nixos = mkOption {
    type = attrsOf (import ./_nodeOptions.nix { inherit lib; });
  };
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
}
