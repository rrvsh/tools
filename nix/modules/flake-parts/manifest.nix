{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (builtins) hasAttr mapAttrs;
  inherit (lib) nixosSystem;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.lists) optional;
  inherit (lib.types)
    bool
    attrsOf
    submodule
    listOf
    deferredModule
    str
    ;
  cfg = config.flake;
  hostOptions = submodule {
    options = {
      arch = mkOption {
        type = str;
        default = "";
        description = "The system architecture for this host.";
      };
      createImage = mkOption {
        type = bool;
        default = false;
        description = ''
          Whether to build an SD image for this host.
          If true, it will appear in `config.flake.images`.
        '';
      };
      modules = mkOption {
        type = listOf deferredModule;
        default = [ ];
        description = "NixOS modules to import for this host.";
      };
    };
  };
  mkImages =
    hosts:
    (mapAttrs (name: _: config.flake.nixosConfigurations.${name}.config.system.build.sdImage)) (
      filterAttrs (_: value: value.createImage) hosts
    );
  mkNixosConfigurations =
    hosts:
    mapAttrs (
      name: value:
      nixosSystem {
        specialArgs = {
          hostName = name;
          hostConfig = value;
        };
        modules = [
          cfg.modules.nixos.default
          cfg.modules.nixos.secrets
          cfg.modules.nixos.nix-config
          cfg.modules.nixos.users
          cfg.modules.nixos.networking
        ]
        ++ (optional (hasAttr name cfg.modules.nixos) cfg.modules.nixos.${name})
        ++ (optional value.createImage cfg.modules.nixos.sd-image)
        ++ (value.modules or [ ]);
      }
    ) hosts;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  options.flake.manifest = {
    hosts.nixos = mkOption {
      default = { };
      type = attrsOf hostOptions;
    };
  };
  config.flake = {
    nixosConfigurations = mkNixosConfigurations cfg.manifest.hosts.nixos;
    images = mkImages cfg.manifest.hosts.nixos;
  };
}
