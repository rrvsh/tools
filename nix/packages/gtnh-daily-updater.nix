{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      version = "0-unstable-2026-06-05";
    in
    {
      packages.gtnh-daily-updater = pkgs.buildGoModule {
        pname = "gtnh-daily-updater";
        inherit version;
        src = inputs.gtnh-daily-updater;
        patches = [ ./patches/gtnh-daily-updater-manifest-file.patch ];
        vendorHash = "sha256-qW5Ybfbo+ss/f9QZv1zTCERhk8cN8I3A3kuPs2eA8rw=";
        nativeCheckInputs = [ pkgs.git ];
        meta = {
          description = "Automated updater for GT: New Horizons daily builds";
          homepage = "https://github.com/Caedis/gtnh-daily-updater";
          mainProgram = "gtnh-daily-updater";
        };
      };
    };
}
