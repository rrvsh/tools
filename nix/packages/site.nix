{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.site-bin = pkgs.rustPlatform.buildRustPackage {
        name = "site";
        src = root + /rs;
        cargoLock.lockFile = root + /rs/Cargo.lock;
      };
    };
}
