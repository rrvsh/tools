# AGENTS.md

## Scope

GitHub automation configuration for CI and deployment.

## Rules

- Keep workflow behavior aligned with `Justfile` and flake outputs.
- Preserve pinned actions and explicit permissions.
- Treat deployment-related edits as high-impact and verify assumptions.

## Subtree Index

- `workflows/`: CI checks, docs validation, and image build/deploy definitions.
