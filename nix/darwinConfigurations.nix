{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
  profileModule = profile: builtins.getAttr "profile-${profile}" cfg.modules.darwin;
  mkDarwinSystem =
    name: value:
    inputs.nix-darwin.lib.darwinSystem {
      modules = [
        {
          networking.hostName = name;
          nixpkgs = { inherit (value) hostPlatform; };
        }
        cfg.modules.darwin.profile-default
      ]
      ++ map profileModule value.profiles
      ++ value.modules;
    };
in
{
  options.flake.hosts.darwin = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          hostPlatform = lib.mkOption {
            type = lib.types.str;
          };
          profiles = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          modules = lib.mkOption {
            type = lib.types.listOf lib.types.deferredModule;
            default = [ ];
          };
        };
      }
    );
    default = { };
  };
  config.flake.darwinConfigurations = builtins.mapAttrs mkDarwinSystem cfg.hosts.darwin;
}
