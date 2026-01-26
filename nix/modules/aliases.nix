{
  config.flake = {
    modules.homeManager.rafiq = {
      home.shellAliases = {
        v = "$EDITOR";
        e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
      };
    };
  };
}
