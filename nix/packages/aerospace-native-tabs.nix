{
  config,
  inputs,
  ...
}:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      fetchDependency =
        {
          hash,
          owner,
          repo,
          rev,
        }:
        pkgs.fetchFromGitHub {
          inherit
            hash
            owner
            repo
            rev
            ;
        };
      hotKey = fetchDependency {
        owner = "soffes";
        repo = "HotKey";
        rev = "a3cf605d7a96f6ff50e04fcb6dea6e2613cfcbe4";
        hash = "sha256-t6HExQe+yXa951inZHfOILNsDrcFxNxPmrBhKtmL6eA=";
      };
      soundAdditions = fetchDependency {
        owner = "InerziaSoft";
        repo = "ISSoundAdditions";
        rev = "4b555f0354e6c280917bae8a598a258efe87ab98";
        hash = "sha256-tCv5XtyMOq0ZOeNPaWXryTg57KsZCpyisc3NQziIQs0=";
      };
      swiftCollections = fetchDependency {
        owner = "apple";
        repo = "swift-collections";
        rev = "7b847a3b7008b2dc2f47ca3110d8c782fb2e5c7e";
        hash = "sha256-Bhfmf02JbmEdM1TFdM8UGxlouR8kr61WlU1uI2v67v8=";
      };
      tomlDecoder = fetchDependency {
        owner = "dduan";
        repo = "TOMLDecoder";
        rev = "fa1103a62b1c08cc08eabc58dda8b55887ff1622";
        hash = "sha256-YOR8nAp89zJOk2ZkmISfdzYJm6euuNrTJmOHcfpptco=";
      };
      swiftSdk = inputs.nixpkgs-swift-sdk.legacyPackages.${system}.apple-sdk_26.src;
      swiftToolchain = pkgs.stdenvNoCC.mkDerivation {
        pname = "swift-toolchain";
        version = "6.3.2";
        src = pkgs.fetchurl {
          url = "https://download.swift.org/swift-6.3.2-release/xcode/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE-osx.pkg";
          hash = "sha256-Pdjac2MYtvCl18AbA53YUR95lMq6v5sQU03OGxnM3Kc=";
        };
        nativeBuildInputs = with pkgs; [
          cpio
          gzip
          xar
        ];
        unpackPhase = ''
          runHook preUnpack
          xar -xf "$src"
          gzip -dc swift-6.3.2-RELEASE-osx-package.pkg/Payload | cpio -idm
          runHook postUnpack
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -R usr/. "$out"
          runHook postInstall
        '';
        dontFixup = true;
      };
    in
    {
      packages = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        aerospace-native-tabs = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "aerospace-native-tabs";
          version = "0.21.3-Beta-native-tabs-5baec50";
          src = pkgs.fetchFromGitHub {
            owner = "nikitabobko";
            repo = "AeroSpace";
            rev = "d56e1637c3a1ed660d0cadd7534e94fb3218d1c3";
            hash = "sha256-NxSqiZKfYBkyX9pRhwT9pnQl54PpkyyDZYRfGrfg/5Q=";
          };
          patches = [
            (root + /nix/packages/aerospace-native-tabs/0001-native-tab-debug-probe.patch)
            (root + /nix/packages/aerospace-native-tabs/0002-native-tab-groups.patch)
            (root + /nix/packages/aerospace-native-tabs/0003-native-tab-focus.patch)
          ];
          nativeBuildInputs = [
            swiftToolchain
            pkgs.darwin.binutils-unwrapped
          ];
          strictDeps = true;
          postPatch = ''
            mkdir -p .deps
            ln -s ${hotKey} .deps/HotKey
            ln -s ${soundAdditions} .deps/ISSoundAdditions
            ln -s ${swiftCollections} .deps/swift-collections
            ln -s ${tomlDecoder} .deps/TOMLDecoder
            substituteInPlace Package.swift \
              --replace-fail '.package(url: "https://github.com/InerziaSoft/ISSoundAdditions.git", exact: "2.0.1")' '.package(path: ".deps/ISSoundAdditions")' \
              --replace-fail '.package(url: "https://github.com/dduan/TOMLDecoder", exact: "0.4.4")' '.package(path: ".deps/TOMLDecoder")' \
              --replace-fail '.package(url: "https://github.com/apple/swift-collections.git", exact: "1.3.0")' '.package(path: ".deps/swift-collections")' \
              --replace-fail '.package(url: "https://github.com/soffes/HotKey.git", exact: "0.2.1")' '.package(path: ".deps/HotKey")'
            substituteInPlace Sources/Common/versionGenerated.swift \
              --replace-fail 'public let aeroSpaceAppVersion = "0.0.0-SNAPSHOT"' 'public let aeroSpaceAppVersion = "${finalAttrs.version}"'
            substituteInPlace Sources/Common/gitHashGenerated.swift \
              --replace-fail 'public let gitHash = "SNAPSHOT"' 'public let gitHash = "5baec5050c7884db049d074deb4538fea37e2884"' \
              --replace-fail 'public let gitShortHash = "SNAPSHOT"' 'public let gitShortHash = "5baec50"'
            # The release-only fallback cannot reach its build tree. Use a stable path so
            # Swift does not embed Nix's random temporary build directory in the binary.
            substituteInPlace Sources/AppBundle/config/Config.swift \
              --replace-fail 'var url = URL(filePath: #filePath)' 'var url = URL(filePath: "/build/source/Sources/AppBundle/config/Config.swift")'
          '';
          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR"
            export SDKROOT=${swiftSdk}
            swift build -c release --disable-sandbox --product AeroSpaceApp
            swift build -c release --disable-sandbox --product aerospace
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            cp -R ${pkgs.aerospace}/. "$out"
            chmod -R u+w "$out"
            rm -rf "$out/Applications/AeroSpace.app/Contents/_CodeSignature"
            install -m755 .build/release/AeroSpaceApp "$out/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"
            install -m755 .build/release/aerospace "$out/bin/aerospace"
            for binary in "$out/Applications/AeroSpace.app/Contents/MacOS/AeroSpace" "$out/bin/aerospace"; do
              strip -S "$binary"
              install_name_tool -delete_rpath ${swiftToolchain}/lib/swift-6.2/macosx "$binary"
            done
            /usr/bin/codesign --force --sign - --timestamp=none "$out/bin/aerospace"
            /usr/bin/codesign --force --deep --sign - --timestamp=none "$out/Applications/AeroSpace.app"
            runHook postInstall
          '';
          meta = {
            description = "AeroSpace with experimental native macOS tab support";
            homepage = "https://github.com/luhw-dev/AeroSpace/tree/native-tabs";
            license = pkgs.lib.licenses.mit;
            mainProgram = "aerospace";
            platforms = pkgs.lib.platforms.darwin;
          };
        });
      };
    };
}
