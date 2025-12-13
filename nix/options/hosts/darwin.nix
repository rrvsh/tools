{ lib, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf raw;
in
{
  options.flake.hosts.darwin = mkOption { type = attrsOf raw; };
  config.flake.modules.darwin.default =
    { hostName, ... }:
    {
      networking.hostName = hostName;
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
