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
          cfg.packages.${pkgs.stdenv.hostPlatform.system}.yt-meta
        ];

        home.shellAliases = {
          v = "$EDITOR";
          e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
          pedia = "process \"$HOME/1_repos/pedia\"";
          day = "v ~/0_library/notes/daily/$(date +%F).md";
          month = "v ~/0_library/notes/monthly/$(date +%Y-%m).md";
        };
      };
  };
}
