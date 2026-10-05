{ config, inputs, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.keybr-tui = pkgs.rustPlatform.buildRustPackage {
        pname = "keybr-tui";
        version = "0.2.4";
        src = inputs.keybr-tui;
        cargoLock.lockFile = inputs.keybr-tui + "/Cargo.lock";
        patches = [ (root + "/nix/packages/patches/keybr-tui-once.patch") ];
        meta = {
          description = "Adaptive terminal typing trainer with one-lesson mode";
          homepage = "https://github.com/y0sif/keybr-tui";
          # The source declares MIT, but the embedded keybr.com model and word list are AGPL-3.0.
          license = pkgs.lib.licenses.agpl3Only;
          mainProgram = "keybr-tui";
          platforms = pkgs.lib.platforms.unix;
        };
      };
    };
}
