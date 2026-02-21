{ config, inputs, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    {
      packages.git-peer-sync = pkgs.rustPlatform.buildRustPackage {
        name = "git-peer-sync";
        src = config.flake.paths.root + /rs;
        cargoLock.lockFile = config.flake.paths.root + /rs/Cargo.lock;
        cargoBuildFlags = [
          "-p"
          "git-peer-sync"
        ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        nativeCheckInputs = [ pkgs.git ];
        postFixup = ''
          wrapProgram "$out/bin/git-peer-sync" \
            --prefix PATH : ${pkgs.lib.makeBinPath [
              pkgs.git
              pkgs.openssh
            ]}
        '';
      };
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
}
