{ config, inputs, ... }:
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
          Env = [ "SITE_CONTENT_DIR=${inputs.site-content}" ];
          Entrypoint = [
            "/bin/sh"
            "-c"
          ];
          Cmd = [ "/bin/site" ];
        };
      };
    };
}
