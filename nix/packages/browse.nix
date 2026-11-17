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

        cargoBuildFlags = [
          "-p"
          "browse"
        ];
        # On macOS, the legacy-client rejection closes one test connection with
        # ECONNRESET instead of the response shape asserted by this Linux-passing test.
        checkFlags = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          "--skip"
          "tells_a_typescript_client_to_restart"
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
        nativeInstallCheckInputs = [ pkgs.python3 ];
        installCheckPhase = ''
          runHook preInstallCheck

          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"

          version="$($out/bin/browse --version)"
          test "$version" = "${finalAttrs.version}"
          $out/bin/browse --help | grep -F "browse lets your AI agents use your real Chrome-family browser"
          $out/bin/browse tools | grep -E '^  execute +'
          $out/bin/browse tools | grep -E '^  status +'
          $out/bin/browse tools | grep -E '^  tabs +'

          python3 - "$out/bin/browse" "${finalAttrs.version}" <<'PY'
          import json
          import subprocess
          import sys

          process = subprocess.Popen(
              [sys.argv[1], "mcp"],
              stdin=subprocess.PIPE,
              stdout=subprocess.PIPE,
              stderr=subprocess.PIPE,
              text=True,
          )
          request = {
              "jsonrpc": "2.0",
              "id": 1,
              "method": "initialize",
              "params": {
                  "protocolVersion": "2025-06-18",
                  "capabilities": {},
                  "clientInfo": {"name": "nix-install-check", "version": "1"},
              },
          }
          stdout, stderr = process.communicate(json.dumps(request) + "\n", timeout=20)
          if process.returncode != 0:
              raise SystemExit(f"browse mcp failed ({process.returncode}): {stderr}")
          response = json.loads(stdout.splitlines()[0])
          assert response["id"] == 1, response
          assert response["result"]["serverInfo"] == {
              "name": "browse",
              "version": sys.argv[2],
          }, response
          PY

          runHook postInstallCheck
        '';

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
