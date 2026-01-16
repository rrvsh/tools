{ lib, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf raw;
in
{
  options.flake.hosts.darwin = mkOption {
    type = attrsOf raw;
    default = { };
    description = "Attribute set where each member is a darwin host.";
  };
  config.flake = {
    modules.darwin.default =
      { hostName, ... }:
      {
        networking.hostName = hostName;
      };
  };
}
