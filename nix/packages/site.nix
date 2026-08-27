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
      siteContentRefresh = pkgs.writeShellApplication {
        name = "site-content-refresh";
        runtimeInputs = with pkgs; [
          coreutils
          git
          git-lfs
          systemd
          util-linux
        ];
        text = ''
          content_dir=/var/lib/site/content
          content_parent=/var/lib/site
          content_repo=https://github.com/rrvsh/site-content.git
          content_branch=prime

          run_as_site() {
            runuser -u site -- env HOME="$content_parent" PATH="$PATH" "$@"
          }

          if [ ! -d "$content_dir/.git" ]; then
            echo "site content: cloning $content_repo into $content_dir"
            mkdir -p "$content_parent"
            chown site:site "$content_parent"
            run_as_site git clone --branch "$content_branch" "$content_repo" "$content_dir"
            run_as_site git -C "$content_dir" lfs install --local
            run_as_site git -C "$content_dir" lfs pull
            echo "site content: restarting site.service"
            systemctl restart site.service
            exit 0
          fi

          run_as_site git -C "$content_dir" lfs install --local
          run_as_site git -C "$content_dir" fetch origin "$content_branch"
          local_rev=$(run_as_site git -C "$content_dir" rev-parse HEAD)
          remote_rev=$(run_as_site git -C "$content_dir" rev-parse "origin/$content_branch")

          if [ "$local_rev" = "$remote_rev" ]; then
            echo "site content: unchanged at $local_rev"
            exit 0
          fi

          echo "site content: updating $local_rev -> $remote_rev"
          run_as_site git -C "$content_dir" pull --ff-only
          run_as_site git -C "$content_dir" lfs pull
          echo "site content: restarting site.service"
          systemctl restart site.service
        '';
      };
    in
    {
      packages = {
        site-bin = siteBin;
        site-deploy = siteDeploy;
      }
      // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
        site-content-refresh = siteContentRefresh;
      };
    };
}
