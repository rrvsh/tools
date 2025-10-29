{ config, ... }:
let
  inherit (config.flake) dependencies;
in
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv) mkDerivation;
    in
    {
      packages.default = mkDerivation {
        name = "";
        # src = ../src;
        buildInputs = dependencies pkgs;
      };
    };
}
