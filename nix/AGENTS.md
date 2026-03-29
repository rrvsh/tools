## Checks and Tests

After making nix changes, run these to auto-fix:
- Run `just format-nix` to format nix files.
- Run `just lint-nix` to lint and fix nix files.

Run these to check before handing off to user:
- Run `just check-nix` to run checks.
- Run `just test-nix` to test nix flakes.

## Module Imports

flake-parts modules and nixos/darwin/home-manager modules both receive `config` as their first parameter, but what `config` contains differs by scope:

At the file level, `config` is flake-parts config, while at the module level, it is the nixos/darwin/home-manager config:
```nix
{ config, ... }:
let 
  cfg = config.flake;
in
{
  config.flake.modules.nixos.rafiq = { config, ... }:
  {
    # config here is nixos/darwin/home-manager config
    # cfg here is flake-parts config (modules, paths)
  };
}
```

Use direct path access (e.g., `inputs.nixpkgs.lib.nixosSystem`) when the binding is used only once. Use `let ... inherit` when a binding is referenced multiple times.
