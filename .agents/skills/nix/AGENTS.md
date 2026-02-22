# AGENTS.md

## Scope

Nix flake architecture conventions used by this repository.

## Rules

- Follow the flake-parts module structure and local wiring conventions.
- Keep reusable logic in modules and host choices in configs.
- Avoid ad hoc path-based imports when module references exist.
