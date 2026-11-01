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
              profiles = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
              modules = lib.mkOption {
                type = lib.types.listOf lib.types.deferredModule;
                default = [ ];
              };
              extraConfig = lib.mkOption {
                type = lib.types.deferredModule;
                default = { };
              };
              machineModules = lib.mkOption {
                type = lib.types.listOf lib.types.deferredModule;
                default = [ ];
              };
              extraMachineConfig = lib.mkOption {
                type = lib.types.deferredModule;
                default = { };
              };
              vm = lib.mkOption {
                default = { };
                type = lib.types.submodule {
                  options = {
                    enable = lib.mkEnableOption "a derived QEMU virtual machine";
                    profiles = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                    };
                    modules = lib.mkOption {
                      type = lib.types.listOf lib.types.deferredModule;
                      default = [ ];
                    };
                    extraConfig = lib.mkOption {
                      type = lib.types.deferredModule;
                      default = { };
                    };
                    memorySize = lib.mkOption {
                      type = lib.types.ints.positive;
                      default = 8192;
                    };
                    cores = lib.mkOption {
                      type = lib.types.ints.positive;
                      default = 8;
                    };
                    diskSize = lib.mkOption {
                      type = lib.types.ints.positive;
                      default = 32768;
                    };
                  };
                };
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
          includeExtraConfig ? false,
          includeMachineConfig ? false,
          systemKind ? "machine",
        }:
        name: value:
        systemBuilder {
          specialArgs = {
            hostName = name;
            inherit systemKind;
            inherit (value) primaryUser;
          };
          modules = [
            {
              networking.hostName = name;
              nixpkgs = { inherit (value) hostPlatform; };
              home-manager.extraSpecialArgs = {
                hostName = name;
                inherit systemKind;
                inherit (value) primaryUser;
              };
            }
            platformModules.profile-default
          ]
          ++ map (profile: builtins.getAttr "profile-${profile}" platformModules) value.profiles
          ++ value.modules
          ++ lib.optional includeExtraConfig value.extraConfig
          ++ lib.optionals includeMachineConfig value.machineModules
          ++ lib.optional includeMachineConfig value.extraMachineConfig;
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
