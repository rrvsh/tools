{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins)
    attrNames
    ;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
in
{
  options.flake.externals.nginx.node = mkOption {
    type = enum (attrNames cfg.nodes.nixos);
  };
  config.flake.modules.nixos.default =
    { hostName, ... }:
    {
      config = mkIf (hostName == cfg.externals.nginx.node) {
        networking.firewall.allowedTCPPorts = [
          80 # HTTP
          443 # HTTPS
        ];
        services.nginx.enable = true;
      };
    };
}
