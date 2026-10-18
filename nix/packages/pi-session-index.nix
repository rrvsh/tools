{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.pi-session-index = pkgs.rustPlatform.buildRustPackage {
        pname = "pi-session-index";
        version = "0.1.0";
        src = root + /rs/pi-session-index;
        cargoLock.lockFile = root + /rs/pi-session-index/Cargo.lock;
      };
    };
}
