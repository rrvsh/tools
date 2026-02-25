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
          (pkgs.writeShellScriptBin "fooc" (
            lib.fileContents (cfg.paths.root + "/scripts/fuzzy-open-or-create.sh")
          ))
        ];

        home.shellAliases = {
          v = "$EDITOR";
          e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
          lib = "fooc \"$HOME/0_library\"";
          process = "fooc \"$HOME/0_library/notes/process\"";
          day = "v ~/0_library/notes/daily/$(date +%F).md";
          month = "v ~/0_library/notes/monthly/$(date +%Y-%m).md";
        };
      };
  };
}
