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
    modules.darwin.leaf = common;
  };
}
