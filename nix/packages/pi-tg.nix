{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    let
      sourceTarball = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@atharva-again/pi-tg/-/pi-tg-0.1.3.tgz";
        hash = "sha512-N/YKbluIabfS5pNW+d92Zk6YbZ/gM1Rj/CwrIifuPcyYKBi8H6xNr/67tsIEwz3wBSqZd5C/KxRdK5f60Hhx3g==";
      };
    in
    {
      packages.pi-tg = pkgs.buildNpmPackage rec {
        pname = "pi-tg";
        version = "0.1.3";

        src = sourceTarball;
        sourceRoot = "package";
        postPatch = ''
          cp ${root + /nix/packages/pi-tg-package-lock.json} package-lock.json
        '';

        npmDepsHash = "sha256-bXwhVmYJsI6uF6BWtKmaKmhsoVAezNUwVoHMsgomOi4=";
        dontNpmBuild = true;

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/lib/node_modules/${pname}" "$out/bin"
          cp -R . "$out/lib/node_modules/${pname}"
          makeWrapper ${pkgs.nodejs_22}/bin/node "$out/bin/pi-tg" \
            --add-flags "$out/lib/node_modules/${pname}/dist/cli.js"
          runHook postInstall
        '';

        meta = {
          description = "Telegram client for Pi";
          homepage = "https://github.com/atharva-again/pi/tree/67187e9eb7a8323df6bff308386e2a3b2591ca05/packages/telegram";
          license = pkgs.lib.licenses.mit;
          mainProgram = "pi-tg";
          platforms = pkgs.lib.platforms.unix;
        };
      };
    };
}
