{ config, lib, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellScriptBin "fooc" (
          lib.fileContents (cfg.paths.root + "/scripts/fuzzy-open-or-create.sh")
        ))
      ];
    };
}
