{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
  profileModule = profile: builtins.getAttr "profile-${profile}" cfg.modules.nixos;
  mkNixosSystem =
    name: value:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        { networking.hostName = name; }
        cfg.modules.nixos.profile-default
      ]
      ++ map profileModule value.profiles
      ++ value.modules;
    };
in
{
  options.flake.hosts.nixos = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
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
  config.flake.nixosConfigurations = builtins.mapAttrs mkNixosSystem cfg.hosts.nixos;
}
