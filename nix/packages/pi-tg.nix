{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.pi-tg = pkgs.buildNpmPackage {
        pname = "pi-tg";
        version = "0.1.3";

        src = inputs.pi-tg;
        postPatch = ''
          cp ${./pi-tg-package-lock.json} package-lock.json
        '';

        npmDepsHash = "sha256-bXwhVmYJsI6uF6BWtKmaKmhsoVAezNUwVoHMsgomOi4=";
        dontNpmBuild = true;

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/lib/node_modules/pi-tg" "$out/bin"
          cp -R . "$out/lib/node_modules/pi-tg"
          makeWrapper ${pkgs.nodejs_22}/bin/node "$out/bin/pi-tg" \
            --add-flags "$out/lib/node_modules/pi-tg/dist/cli.js"
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
