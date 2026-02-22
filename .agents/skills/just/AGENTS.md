# AGENTS.md

## Scope

Workflow guidance for local commands defined in `Justfile`.

## Rules

- Use `just nice` for formatting and automatic lint fixes.
- Use `just check` for CI-parity checks.
- Do not run `just rb` unless the user explicitly asks for a system rebuild.
