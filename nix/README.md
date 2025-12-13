# nix

## general formatting RULES:
- nix code blocks:
    - 2 space indents
    - optional comment name of file first line
    - optional wrap in curly braces to denote files
    - refer to modules by full path e.g. `config.flake` instead of `flake`
- nix code:
    - prefer including source of variables instead of inheriting them

## RULES:

structure all files as "libraries" and "modules" or think of them as their outputs for example:

```nix
# rafiq.nix
{
  # this provides a "rafiq library" for other modules under a common API users.users.<name>
  config.flake.users.users.rafiq = {
    primary = true; # marks this user as the one who is able to build the machines and administer them
    fullName = "Mohammad Rafiq";
    email = "rafiq@rrv.sh";
    # setting pubkeys for all machines will enable us to use tailscale ssh for essentially everything
    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
    needs = {
      browser = "firefox";
      terminal = "ghostty";
    };
  };
  # this provides a "rafiq module" for use in nixos, darwin, and home-manager configurations
  # it likely relies on other modules libraries
  config.flake.modules = {
    nixos.rafiq = {...};
    darwin.rafiq = {...};
    homeManager.rafiq = {...};
  };
}
```
