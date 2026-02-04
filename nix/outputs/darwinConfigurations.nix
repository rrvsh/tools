# Constructs darwinConfigurations from config.flake.modules.darwin.{default, hostName},
# where hostName is the defined name of the machine
{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf raw;
in
{
  options.flake.hosts.darwin = mkOption {
    type = attrsOf raw;
    default = { };
    description = "Attribute set where each member is a darwin host.";
  };
  config.flake = {
    darwinConfigurations = mapAttrs (
      hostName: host:
      inputs.nix-darwin.lib.darwinSystem {
        specialArgs = { inherit hostName; };
        modules = [
          cfg.modules.darwin.default
          (cfg.modules.darwin.${hostName} or { })
        ]
        ++ (host.modules or [ ]);
      }
    ) cfg.hosts.darwin;
    modules.darwin.default =
      { hostName, ... }:
      {
        networking.hostName = hostName;
      };
  };
}
