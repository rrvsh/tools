{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib) nixosSystem;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) optional;
  mkImages =
    hosts:
    (mapAttrs (name: _: config.flake.nixosConfigurations.${name}.config.system.build.sdImage)) (
      filterAttrs (_: value: value.createImage) hosts
    );
  mkNixosConfigurations =
    hosts:
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
        ++ (optional value.createImage cfg.modules.nixos.sd-image)
        ++ (value.modules or [ ]);
      }
    ) hosts;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  flake.nixosConfigurations = mkNixosConfigurations cfg.manifest.hosts.nixos;
  flake.images = mkImages cfg.manifest.hosts.nixos;
}
