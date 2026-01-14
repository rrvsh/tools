{ config, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    {
      packages.site-bin = pkgs.rustPlatform.buildRustPackage {
        name = "site";
        src = config.flake.paths.root + /rs;
        cargoLock.lockFile = config.flake.paths.root + /rs/Cargo.lock;
      };
      packages.site-image = pkgs.dockerTools.buildLayeredImage {
        name = "site";
        tag = "latest";
        contents = [
          self'.packages.site-bin
          pkgs.dockerTools.binSh
        ];
        config = {
          Entrypoint = [
            "/bin/sh"
            "-c"
          ];
          Cmd = [ "/bin/site" ];
        };
      };
    };
}
