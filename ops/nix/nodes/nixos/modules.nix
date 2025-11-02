{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib) nixosSystem;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    deferredModule
    attrsOf
    submoduleWith
    listOf
    ;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  options.flake.nodes.nixos = mkOption {
    type = attrsOf (submoduleWith {
      modules = [
        {
          options = {
            modules = mkOption {
              type = listOf deferredModule;
              default = [ ];
            };
          };
        }
      ];
    });
  };
  config.flake.nixosConfigurations = mapAttrs (
    name: value:
    nixosSystem {
      specialArgs = {
        hostName = name;
        hostConfig = value;
      };
      modules = [ cfg.modules.nixos.default ] ++ value.modules;
    }
  ) cfg.nodes.nixos;
}
