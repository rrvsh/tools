{
  config.flake = {
    modules.homeManager.rafiq = {
      home.shellAliases = {
        v = "$EDITOR";
        e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
        "in" = "mkdir -p ~/ref && $EDITOR ~/ref/inbox.md";
        out = "mkdir -p ~/ref && $EDITOR ~/ref/out.md";
        projects = "mkdir -p ~/ref/projects && $EDITOR ~/ref/projects/projects.md";
      };
    };
  };
}
