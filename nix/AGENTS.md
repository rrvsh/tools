# AGENTS.md

## Scope

Root of flake module architecture for hosts, reusable modules, and outputs.

## File Index

- `imports.nix`: import tree glue.
- `systems.nix`: supported systems list.

## Rules

- Keep host-specific composition in `configs/`.
- Keep reusable behavior in `modules/`.
- Keep flake outputs assembly in `outputs/`.
- Follow conventions in `.agents/skills/nix/SKILL.md`.

## Subtree Index

- `configs/`: host-specific module selections.
- `modules/`: reusable NixOS, nix-darwin, and home-manager modules.
- `outputs/`: generated flake outputs (configs, packages, shells).
