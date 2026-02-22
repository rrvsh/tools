# AGENTS.md

## Scope

Host-specific configuration composition.

## File Index

- `alpha.nix`: host profile for darwin machine `alpha`.
- `nemesis.nix`: host profile for nixos machine `nemesis`.

## Rules

- Use this directory for host-only module selections and overrides.
- Keep cross-host logic in `../modules/` instead of duplicating here.
