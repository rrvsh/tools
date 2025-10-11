{ lib, config, ... }:
let
  inherit (builtins) mapAttrs;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.types) bool attrsOf submodule;
  cfg = config.flake;
  mkImages =
    hosts:
    (mapAttrs (name: _: config.flake.nixosConfigurations.${name}.config.system.build.sdImage)) (
      filterAttrs (_: value: value.createImage) hosts
    );
  hostOptions = submodule {
    options = {
      createImage = mkOption {
        type = bool;
        default = false;
        description = ''
          Whether to build an SD image for this host.
          If true, it will appear in `config.flake.images`.
        '';
      };
    };
  };
in
{
  options.flake.manifest = {
    hosts.nixos = mkOption {
      default = { };
      type = attrsOf hostOptions;
    };
  };
  config.flake = {
    images = mkImages cfg.manifest.hosts.nixos;
    manifest.hosts.nixos.veil.createImage = true;
  };
}
