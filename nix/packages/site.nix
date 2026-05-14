{ config, inputs, ... }:
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
    in
    {
      packages.site-bin = siteBin;

      packages.site-deploy = pkgs.stdenvNoCC.mkDerivation {
        pname = "site-deploy";
        version = "0.1.0";
        dontUnpack = true;
        nativeBuildInputs = [ pkgs.rsync ];
        buildCommand = ''
          mkdir -p "$out/bin" "$out/static" "$out/content"

          install -m0755 "${siteBin}/bin/site" "$out/bin/site"

          rsync -a --delete \
            "${root}/rs/site/static/" \
            "$out/static/"

          rsync -a --delete \
            "${inputs.site-content}/" \
            "$out/content/"
        '';
      };
    };
}
