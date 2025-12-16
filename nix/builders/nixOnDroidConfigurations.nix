# Constructs nixOnDroidConfigurations from config.flake.modules.nixOnDroid.{default, hostName},
# where hostName is the defined name of the machine
{ inputs, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
in
{
  config.flake.nixOnDroidConfigurations = mapAttrs (
    hostName: _:
    inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      # specialArgs = { inherit hostName; };
      pkgs = import inputs.nixpkgs-2405 { system = "aarch64-linux"; };
      modules = [
        (cfg.modules.droid.default or { })
        (cfg.modules.droid.${hostName} or { })
      ];
    }
  ) cfg.hosts.droid;
}
