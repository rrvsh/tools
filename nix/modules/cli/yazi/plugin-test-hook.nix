{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      home.activation.test-yazi-plugin = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${
          pkgs.writeShellScriptBin "test-yazi-plugin" (
            lib.fileContents (cfg.paths.root + "/scripts/test-yazi-plugin.sh")
          )
        }/bin/test-yazi-plugin || true
      '';
    };
}
