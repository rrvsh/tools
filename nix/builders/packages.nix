{ config, ... }:
let
  src = config.flake.paths.root + /rs;
  cargoLock.lockFile = src + /Cargo.lock;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.rrvsh = pkgs.rustPlatform.buildRustPackage {
        inherit src cargoLock;
        name = "rrvsh";
        cargoBuildFlags = [ "--package rrvsh" ];
      };
    };
}
