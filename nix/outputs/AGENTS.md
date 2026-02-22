# AGENTS.md

## Scope

Assembly layer for flake outputs.

## File Index

- `darwinConfigurations.nix`: nix-darwin host outputs.
- `nixosConfigurations.nix`: NixOS host outputs.
- `packages.nix`: build outputs including Rust site package and image.
- `devShells.nix`: development shell outputs.
- `allowedUnfreePackages.nix`: unfree package allowlist.

## Rules

- Keep outputs derived from `nix/configs` and `nix/modules` composition.
- Avoid embedding host-specific logic directly in output files.
