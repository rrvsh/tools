{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.isLinux {
        hermes-workspace-cleanup = pkgs.writeShellApplication {
          name = "hermes-workspace-cleanup";
          runtimeInputs = with pkgs; [
            coreutils
            findutils
            jq
            util-linux
          ];
          text = builtins.readFile (root + /nix/scripts/hermes-workspace-cleanup.sh);
        };
      };
    };
}
