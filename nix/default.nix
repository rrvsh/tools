{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake = {
    modules.nixos.default.imports = [ cfg.modules.nixos.tailscale ];
    modules.darwin.default.imports = [ cfg.modules.darwin.tailscale ];
  };
}
