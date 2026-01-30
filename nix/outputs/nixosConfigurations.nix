# Constructs nixosConfigurations from config.flake.modules.nixos.{default, hostName},
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
  options.flake.hosts.nixos = mkOption {
    type = attrsOf raw;
    default = { };
    description = "Attribute set where each member is a nixos host.";
  };
  config.flake = {
    nixosConfigurations = mapAttrs (
      hostName: host:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit hostName; };
        modules = [
          cfg.modules.nixos.default
          (cfg.modules.nixos.${hostName} or { })
        ]
        ++ (host.modules or [ ]);
      }
    ) cfg.hosts.nixos;
    modules.nixos.default =
      { hostName, ... }:
      {
        networking.hostName = hostName;
      };
  };
}
