# Nix Configuration Guidelines

## Checks and Tests

After making nix changes, run these to auto-fix:
- `just format-nix` to format nix files
- `just lint-nix` to lint and fix nix files

Run these to check before handing off to user:
- `just check-nix` to run checks
- `just test-nix` to test nix flakes (use ALL_SYSTEMS=1 for all-systems)

## Code Style

flake-parts Modules:
- Modules receive `config` as first parameter
- At file level, `config` is flake-parts config
- At module level (nixos/darwin/home-manager), `config` is the system config
- Use `let ... inherit` when a binding is referenced multiple times; direct path access when used once

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

Imports Pattern:
```nix
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.hyprland.nixosModules.default
  ];
}
```

Attribute Sets: Use multi-line format for large attr sets.

Special Paths: Use `config.flake.paths.root` to reference repository root.

Nixpkgs Lib: Access via `inputs.nixpkgs.lib`.

## Module Imports

flake-parts modules and nixos/darwin/home-manager modules both receive `config` as their first parameter, but what `config` contains differs by scope:

Use direct path access (e.g., `inputs.nixpkgs.lib.nixosSystem`) when the binding is used only once. Use `let ... inherit` when a binding is referenced multiple times.

## Nix Flake Inputs

Key inputs in `flake.nix`:
- `nixpkgs`: nixos-unstable
- `home-manager`: nix-community/home-manager
- `flake-parts`: hercules-ci/flake-parts
- `hyprland`: hyprwm/Hyprland
- `nix-darwin`: nix-darwin master
- `sops-nix`: Mic92/sops-nix

## Dev Shells

```bash
nix develop .#ci-nix     # for nix linting/checking
nix develop .#ci-rust    # for rust development
nix develop .#ci-lua     # for lua checking
nix develop .#ci-gha     # for GHA checking
nix develop .#ci-all     # all tools
```

## Gotchas

- `treefmt` is not in bare PATH - always run via `nix develop .#ci-nix -c treefmt`
- `just check-nix` runs `treefmt --ci` which also needs the nix wrapper
- `nh os switch` and `nh darwin switch` work on Linux for their respective configs
- Nix shell hooks for Rust (used in devShells):
  ```nix
  shellHook = ''
    export CARGO_HOME="$HOME/.cache/tools/cargo"
    export RUSTUP_HOME="$HOME/.cache/tools/rustup"
    mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
  '';
  ```

## Nix Flake Outputs

The `modules` and `paths` outputs are used internally by flake-parts. `nix flake check` may warn about unknown outputs - this is normal and not an error.
