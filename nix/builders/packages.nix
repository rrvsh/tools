{ config, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    {
      packages.rrv-sh-bin = pkgs.rustPlatform.buildRustPackage {
        name = "rrv-sh";
        src = config.flake.paths.root + /rs;
        cargoLock.lockFile = config.flake.paths.root + /rs/Cargo.lock;
      };
      packages.rrv-sh-image = pkgs.dockerTools.buildLayeredImage {
        name = "rrv-sh";
        tag = "latest";
        contents = [
          self'.packages.rrv-sh-bin
          pkgs.dockerTools.binSh
        ];
        config = {
          Entrypoint = [
            "/bin/sh"
            "-c"
          ];
          Cmd = [ "/bin/rrv-sh" ];
        };
      };
    };
}
