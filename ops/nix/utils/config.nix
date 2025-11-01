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
        modules = [ cfg.modules.nixos.default ] ++ value.modules;
      }
    ) manifest.nodes.nixos;
  };
}
