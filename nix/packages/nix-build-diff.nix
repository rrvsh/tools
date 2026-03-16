{ config, lib, ... }:
let
  cfg = config.flake;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.nix-build-diff = pkgs.writeShellApplication {
        name = "nbd";
        text = lib.fileContents (cfg.paths.root + "/sh/nix-build-diff.sh");
        runtimeInputs = [ pkgs.nvd ];
      };
    };
}
