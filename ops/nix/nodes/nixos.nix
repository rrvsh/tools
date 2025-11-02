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
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.types) attrsOf;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  options.flake.nodes.nixos = mkOption {
    type = attrsOf (import ./_nodeOptions.nix { inherit lib; });
  };
  config.flake = {
    images = (mapAttrs (name: _: cfg.nixosConfigurations.${name}.config.system.build.sdImage)) (
      filterAttrs (_: value: value.createImage or false) cfg.nodes.nixos
    );
    nixosConfigurations = mapAttrs (
      name: value:
      nixosSystem {
        specialArgs = {
          hostName = name;
          hostConfig = value;
        };
        modules = [ cfg.modules.nixos.default ];
      }
    ) cfg.nodes.nixos;
  };
}
