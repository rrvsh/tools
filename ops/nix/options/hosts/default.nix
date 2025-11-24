{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    attrsOf
    submodule
    str
    deferredModule
    ;
  hostOption = mkOption {
    type = attrsOf (submodule {
      options = {
        platform = mkOption { type = str; };
        extraConfig = mkOption {
          type = deferredModule;
          default = { };
        };
        services = mkOption { type = submodule { options = cfg.hosts.userOptions.apps; }; };
        roles = mkOption { type = submodule { options = cfg.hosts.userOptions.apps; }; };
      };
    });
  };
  common =
    { hostname, hostConfig, ... }:
    {
      networking.hostName = hostname;
      nixpkgs.hostPlatform = hostConfig.platform;
    };
in
{
  options.flake.hosts = {
    darwin = hostOption;
    nixos = hostOption;
  };
  config.flake = {
    darwinConfigurations = mapAttrs (
      hostname: hostConfig:
      inputs.nix-darwin.lib.darwinSystem {
        specialArgs = { inherit hostname hostConfig; };
        modules = [
          cfg.modules.darwin.leaf
          hostConfig.extraConfig
        ];
      }
    ) cfg.hosts.darwin;
    nixosConfigurations = mapAttrs (
      hostname: hostConfig:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit hostname hostConfig; };
        modules = [
          inputs.nixos-generators.nixosModules.all-formats
          cfg.modules.nixos.leaf
          hostConfig.extraConfig
        ];
      }
    ) cfg.hosts.nixos;
    modules.darwin.leaf = common;
    modules.nixos.leaf = common;
  };
}
