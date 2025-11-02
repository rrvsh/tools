{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.types) attrsOf submoduleWith bool;
in
{
  options.flake.nodes.nixos = mkOption {
    type = attrsOf (submoduleWith {
      modules = [
        {
          options = {
            createImage = mkOption {
              type = bool;
              default = false;
            };
          };
        }
      ];
    });
  };
  config.flake.images =
    (mapAttrs (name: _: cfg.nixosConfigurations.${name}.config.system.build.sdImage))
      (filterAttrs (_: value: value.createImage) cfg.nodes.nixos);
  config.flake.modules.nixos.default =
    { hostName, hostConfig, ... }:
    {
      imports = [ "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-${hostConfig.arch}.nix" ];
      config = mkIf hostConfig.createImage {
        image.fileName = "nixos-25-11-${hostConfig.arch}-${hostName}.img";
        sdImage.compressImage = false;
      };
    };
}
