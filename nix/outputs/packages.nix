{ config, inputs, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    {
      packages = {
        hyprctl-split = pkgs.rustPlatform.buildRustPackage {
          pname = "hyprctl-split";
          version = "0.1.0";
          src = config.flake.paths.root + /rs;
          cargoLock.lockFile = config.flake.paths.root + /rs/Cargo.lock;
          cargoBuildFlags = [
            "-p"
            "hyprctl-split"
          ];
          cargoTestFlags = [
            "-p"
            "hyprctl-split"
          ];
        };
        site-bin = pkgs.rustPlatform.buildRustPackage {
          name = "site";
          src = config.flake.paths.root + /rs;
          cargoLock.lockFile = config.flake.paths.root + /rs/Cargo.lock;
        };
        site-image = pkgs.dockerTools.buildLayeredImage {
          name = "site";
          tag = "latest";
          contents = [
            self'.packages.site-bin
            pkgs.dockerTools.binSh
          ];
          config = {
            Env = [
              "SITE_CONTENT_DIR=${inputs.site-content}"
              "STATIC_DIR=${config.flake.paths.root + /rs/site/static}"
            ];
            Entrypoint = [
              "/bin/sh"
              "-c"
            ];
            Cmd = [ "/bin/site" ];
          };
        };
      };
    };
}
