{
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    {
      packages.browse = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
        pname = "opencode-browse";
        version = "0.1.1";

        src = pkgs.fetchFromGitHub {
          owner = "anomalyco";
          repo = "browse";
          tag = "v${finalAttrs.version}";
          hash = "sha256-lvndoaUv9kKdt5Mthblm/CHS3dlICwQz2F/Y2hzrTAY=";
        };

        cargoRoot = "rust";
        buildAndTestSubdir = "rust";
        cargoHash = "sha256-Dv8bZ3qJpvGsIclV8hM7chJXuxBwqOJ51ZBcV0zSAIg=";

        patches = [
          ./patches/browse-test-legacy-get-without-body.patch
          ./patches/browse-macos-hide-after-handoff.patch
          ./patches/browse-hyprland-handoff.patch
        ];

        cargoBuildFlags = [
          "-p"
          "browse"
        ];

        nativeBuildInputs = [ pkgs.makeWrapper ];
        nativeCheckInputs = [ pkgs.curl ] ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.chromium;

        env = {
          BROWSE_VERSION = finalAttrs.version;
          BROWSE_BUILD_ID = "nix-${finalAttrs.version}";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          BROWSE_TEST_CHROME = "${pkgs.chromium}/bin/chromium";
        };

        postInstall = ''
          wrapProgram $out/bin/browse \
            --set OPENCODE_BROWSER_AUTO_UPDATE off
        '';

        doInstallCheck = true;
        nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
        versionCheckProgramArg = "--version";

        meta = {
          description = "MCP server that lets agents use a real Chromium browser";
          homepage = "https://github.com/anomalyco/browse";
          changelog = "https://github.com/anomalyco/browse/blob/v${finalAttrs.version}/changelog/${finalAttrs.version}.md";
          license = lib.licenses.mit;
          sourceProvenance = [ lib.sourceTypes.fromSource ];
          mainProgram = "browse";
          platforms = lib.platforms.unix;
        };
      });
    };
}
