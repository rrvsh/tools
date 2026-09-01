{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3.withPackages (ps: [ ps.playwright ]);
    in
    {
      packages.linkedin-jobs-search = pkgs.stdenvNoCC.mkDerivation {
        pname = "linkedin-jobs-search";
        version = "0-unstable-2026-07-06";
        src = root + /scripts/linkedin-jobs-search;
        dontUnpack = true;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        installPhase = ''
          runHook preInstall
          install -Dm755 $src $out/libexec/linkedin-jobs-search
          makeWrapper ${python}/bin/python $out/bin/linkedin-jobs-search \
            --add-flags $out/libexec/linkedin-jobs-search \
            --set LINKEDIN_JOBS_CHROMIUM ${pkgs.chromium}/bin/chromium
          runHook postInstall
        '';
        meta = {
          description = "Build/fetch deterministic LinkedIn Jobs searches from CLI flags";
          mainProgram = "linkedin-jobs-search";
        };
      };
    };
}
