{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) hasAttr mapAttrs;
  inherit (lib) nixosSystem;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) optional;
  mkImages =
    nodes:
    (mapAttrs (name: _: config.flake.nixosConfigurations.${name}.config.system.build.sdImage)) (
      filterAttrs (_: value: value.createImage) nodes
    );
  mkNixosConfigurations =
    nodes:
    mapAttrs (
      name: value:
      nixosSystem {
        specialArgs = {
          hostName = name;
          hostConfig = value;
        };
        modules = [
          cfg.modules.nixos.default
        ]
        ++ (optional (hasAttr name cfg.modules.nixos) cfg.modules.nixos.${name})
        ++ (optional value.createImage cfg.modules.nixos.sd-image)
        ++ (value.modules or [ ]);
      }
    ) nodes;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  flake.nixosConfigurations = mkNixosConfigurations cfg.manifest.nodes.nixos;
  flake.images = mkImages cfg.manifest.nodes.nixos;
}
