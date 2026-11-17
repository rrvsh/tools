{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      packages.browse =
        let
          artifacts = {
            aarch64-darwin = {
              package = "darwin-arm64";
              hash = "sha512-1fIzN9OrxqD3ZGQ0n7K+iZgRQWIZrUZIsma5FWvSi4haWB1QumsmRNfh1kaRzSOsthn863RbUQvLsplO2KAv2g==";
            };
            aarch64-linux = {
              package = "linux-arm64";
              hash = "sha512-klF2M7mElXniJQ4pDwhtg6m/8FgAx+EDoWzuNN8QlfA/gtYqrG1Hl2j5DsRXxF0s2JrhdJr/Zld9Q2rg8Ncc2Q==";
            };
            x86_64-darwin = {
              package = "darwin-x64";
              hash = "sha512-8wsSqYMW0GWXiURTd5puvPG3rmE2aCnbx6fkT/P9TobYfQ1bGu3K7RgLD0wak4UslzZTNCgYVZhwFhT/jqQ6kA==";
            };
            x86_64-linux = {
              package = "linux-x64";
              hash = "sha512-N0dEMW6hBj8Duzv9lF51uHMUg9TAsJGElJ+NMHMK+yl0rW2PGVc44Lsk4rICe2ctXBHvIdbzQybjTvbGdXXyiQ==";
            };
          };
          artifact = artifacts.${system};
        in
        pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "browse";
          version = "0.1.1";
          src = pkgs.fetchurl {
            url = "https://registry.npmjs.org/@opencode/browse-${artifact.package}/-/browse-${artifact.package}-${finalAttrs.version}.tgz";
            inherit (artifact) hash;
          };
          sourceRoot = "package";
          dontBuild = true;
          nativeBuildInputs = [
            pkgs.makeWrapper
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
          buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];
          installPhase = ''
            runHook preInstall
            install -Dm755 bin/browse $out/libexec/browse
            install -Dm644 LICENSE $out/share/licenses/browse/LICENSE
            # Nix owns Browse updates, so its immutable store binary must not try to replace itself.
            makeWrapper $out/libexec/browse $out/bin/browse \
              --set OPENCODE_BROWSER_AUTO_UPDATE off
            runHook postInstall
          '';
          doInstallCheck = true;
          installCheckPhase = ''
            runHook preInstallCheck
            export HOME="$TMPDIR/browse-home"
            mkdir -p "$HOME"
            "$out/bin/browse" --version | grep -Fx '${finalAttrs.version}'
            "$out/bin/browse" --help >/dev/null
            runHook postInstallCheck
          '';
          meta = {
            description = "Let agents use a real Chromium browser";
            homepage = "https://github.com/anomalyco/browse";
            license = lib.licenses.mit;
            mainProgram = "browse";
            platforms = builtins.attrNames artifacts;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
          };
        });
    };
}
