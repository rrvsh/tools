{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
  profileModule = profile: builtins.getAttr "profile-${profile}" cfg.modules.darwin;
  primaryUserType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      fullName = lib.mkOption { type = lib.types.str; };
      email = lib.mkOption { type = lib.types.str; };
      gitDefaultBranch = lib.mkOption {
        type = lib.types.str;
        default = "main";
      };
      sshAuthorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };
  mkDarwinSystem =
    name: value:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = {
        hostName = name;
        inherit (value) primaryUser;
      };
      modules = [
        (
          { primaryUser, ... }:
          {
            networking.hostName = name;
            nixpkgs = { inherit (value) hostPlatform; };
            home-manager.extraSpecialArgs = {
              hostName = name;
              inherit primaryUser;
            };
          }
        )
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
          primaryUser = lib.mkOption {
            type = primaryUserType;
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
