# AGENTS.md

## Scope

Workflow definitions for CI validation and deployment automation.

## File Index

- `check.yaml`: formatting, linting, testing parity.
- `ensure-docs.yaml`: documentation consistency checks.
- `build-and-push.yaml`: image build, publish, and deploy flow.

## Rules

- Keep shell steps deterministic and failure-forward.
- Keep workflow references pinned and security-conscious.
- Ensure workflow entrypoints match repository commands and outputs.
