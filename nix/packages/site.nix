{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    let
      siteBin = pkgs.rustPlatform.buildRustPackage {
        name = "site";
        src = root + /rs;
        cargoLock.lockFile = root + /rs/Cargo.lock;
      };
      siteDeploy = pkgs.stdenvNoCC.mkDerivation {
        name = "site-deploy";
        dontUnpack = true;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/site
          cp -R ${root + /rs/site/static} $out/share/site/static
          makeWrapper ${siteBin}/bin/site $out/bin/site \
            --set STATIC_DIR $out/share/site/static \
            --prefix PATH : ${
              pkgs.lib.makeBinPath [
                pkgs.git
                pkgs.git-lfs
              ]
            }
          runHook postInstall
        '';
      };
    in
    {
      packages = {
        site-bin = siteBin;
        site-deploy = siteDeploy;
      };
    };
}
