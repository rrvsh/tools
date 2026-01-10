{ config, ... }:
let
  name = "rrvsh";
  src = config.flake.paths.root + /rs;
  cargoLock.lockFile = src + /Cargo.lock;
in
{
  perSystem =
    { pkgs, self', ... }:
    {
      packages = {
        rrvsh-bin = pkgs.rustPlatform.buildRustPackage {
          inherit cargoLock name src;
          cargoBuildFlags = [ "--package ${name}" ];
        };
        rrvsh-image = pkgs.dockerTools.buildLayeredImage {
          inherit name;
          tag = "latest";
          contents = [ self'.packages.rrvsh-bin ];
          config.Cmd = ["/bin/rrvsh"];
        };
      };
    };
}
