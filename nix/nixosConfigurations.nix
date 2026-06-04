{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
  mkNixosSystem =
    name: value:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [ { networking.hostName = name; } ] ++ value.modules;
    };
in
{
  options.flake.hosts.nixos = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          modules = lib.mkOption {
            type = lib.types.listOf lib.types.deferredModule;
            default = [ ];
          };
        };
      }
    );
    default = { };
  };
  config.flake.nixosConfigurations = builtins.mapAttrs mkNixosSystem cfg.hosts.nixos;
}
