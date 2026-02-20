{ config, inputs, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    {
      packages = {
        yt-meta = pkgs.writeShellApplication {
          name = "yt-meta";
          runtimeInputs = with pkgs; [
            yt-dlp
            jq
            ffmpeg
            deno
          ];
          text = ''
            if [ "$#" -ne 1 ]; then
              echo "usage: yt-meta <url>" >&2
              exit 1
            fi

            url="$1"

            yt-dlp \
              --js-runtimes deno \
              --remote-components ejs:npm \
              -J "$url" \
              | jq -r '
                . as $v
                | $v.title + ", "
                + $v.uploader + ", "
                + (
                  if ($v.upload_date | type) == "string" and ($v.upload_date | test("^[0-9]{8}$"))
                  then "\($v.upload_date[6:8])/\($v.upload_date[4:6])/\($v.upload_date[0:4])"
                  else ""
                  end
                )
              '
          '';
        };

        site-bin = pkgs.rustPlatform.buildRustPackage {
          name = "site";
          src = config.flake.paths.root + /rs;
          cargoLock.lockFile = config.flake.paths.root + /rs/Cargo.lock;
        };

        site-image = pkgs.dockerTools.buildLayeredImage {
          name = "site";
          tag = "latest";
          contents = [
            self'.packages.site-bin
            pkgs.dockerTools.binSh
          ];
          config = {
            Env = [
              "SITE_CONTENT_DIR=${inputs.site-content}"
              "STATIC_DIR=${config.flake.paths.root + /rs/site/static}"
            ];
            Entrypoint = [
              "/bin/sh"
              "-c"
            ];
            Cmd = [ "/bin/site" ];
          };
        };
      };
    };
}
