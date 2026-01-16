# Constructs darwinConfigurations from config.flake.modules.darwin.{default, hostName},
# where hostName is the defined name of the machine
{ inputs, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
in
{
  config.flake = {
    darwinConfigurations = mapAttrs (
      hostName: _:
      inputs.nix-darwin.lib.darwinSystem {
        specialArgs = { inherit hostName; };
        modules = [
          cfg.modules.darwin.default
          (cfg.modules.darwin.${hostName} or { })
        ];
      }
    ) cfg.hosts.darwin;
  };
}
