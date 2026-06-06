{ lib, ... }:
let
  toolsLib = {
    hosts = {
      hostOptions = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              hostPlatform = lib.mkOption {
                type = lib.types.str;
              };
              primaryUser = lib.mkOption {
                type = lib.types.submodule {
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
                    uid = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                    };
                  };
                };
              };
              hostName = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
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
      mkSystem =
        {
          systemBuilder,
          platformModules,
        }:
        name: value:
        let
          hostName = if value.hostName == null then name else value.hostName;
        in
        systemBuilder {
          specialArgs = {
            inherit hostName;
            inherit (value) primaryUser;
          };
          modules = [
            {
              networking.hostName = hostName;
              nixpkgs = { inherit (value) hostPlatform; };
              home-manager.extraSpecialArgs = {
                inherit hostName;
                inherit (value) primaryUser;
              };
            }
            platformModules.profile-default
          ]
          ++ map (profile: builtins.getAttr "profile-${profile}" platformModules) value.profiles
          ++ value.modules;
        };
    };
  };
in
{
  config = {
    _module.args.toolsLib = toolsLib;
    flake.lib = toolsLib;
  };
}
