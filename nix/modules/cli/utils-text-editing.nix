{ config, lib, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "fooc";
          text = lib.fileContents (cfg.paths.root + "/sh/fuzzy-open-or-create.sh");
          runtimeInputs = [
            pkgs.ripgrep
            pkgs.skim
            pkgs.gnused
          ];
        })
      ];
      home.shellAliases = {
        v = "$EDITOR";
        e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
        lib = "fooc \"$HOME/0_library\"";
      };
    };
}
