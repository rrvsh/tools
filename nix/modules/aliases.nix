{ config, lib, ... }:
let
  cfg = config.flake;
in
{
  config.flake = {
    modules.homeManager.rafiq =
      { pkgs, ... }:
      {
        home.packages = [
          (pkgs.writeShellScriptBin "process" (lib.fileContents (cfg.paths.root + "/scripts/process.sh")))
        ];

        home.shellAliases = {
          v = "$EDITOR";
          e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
        };
      };
  };
}
