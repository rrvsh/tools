{ config, ... }:
let
  cfg = config.flake;
in
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell { buildInputs = cfg.devenv pkgs; };
    };
}
