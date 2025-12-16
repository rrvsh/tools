{
  config.flake = {
    users.users.rafiq = {
      primary = true;
      email = "rafiq@rrv.sh";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
    };
    modules.homeManager.rafiq = {
      home.shellAliases = {
        v = "$EDITOR";
        e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
        # e.g. 10112025.md
        dy = "mkdir -p ~/ref/source && $EDITOR ~/ref/source/daily/daily-scratchpad-$(date +%d%m%Y).md";
      };
    };
  };
}
