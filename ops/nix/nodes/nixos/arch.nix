{
  lib,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.types)
    attrsOf
    submoduleWith
    str
    ;
in
{
  options.flake.nodes.nixos = mkOption {
    type = attrsOf (submoduleWith {
      modules = [
        {
          options = {
            arch = mkOption { type = str; };
          };
        }
      ];
    });
  };
  config.flake.modules.nixos.default =
    { hostConfig, ... }:
    {
      nixpkgs.hostPlatform.system = "${hostConfig.arch}-linux";
      system.stateVersion = "25.11";
    };
}
