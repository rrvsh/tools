{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg) manifest;
  inherit (builtins) mapAttrs;
  inherit (lib) nixosSystem;
  inherit (lib.attrsets) filterAttrs;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  flake = {
    nixosConfigurations = mapAttrs (
      name: value:
      nixosSystem {
        specialArgs = {
          inherit manifest;
          hostName = name;
          hostConfig = value;
        };
        modules = [ cfg.modules.nixos.default ];
      }
    ) manifest.nodes.nixos;
    images = (mapAttrs (name: _: cfg.nixosConfigurations.${name}.config.system.build.sdImage)) (
      filterAttrs (_: value: value.createImage) manifest.nodes.nixos
    );
  };
}
