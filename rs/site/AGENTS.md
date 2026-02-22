# AGENTS.md

## Scope

Primary web application crate for this repository.

## File Index

- `Cargo.toml`: crate dependencies and metadata.
- `clippy.toml`: lint policy.

## Rules

- Keep HTTP handling in `src/app/controllers/`.
- Keep content/domain loading in `src/app/models/`.
- Keep presentation shaping in `src/app/views/` and Askama templates.

## Subtree Index

- `src/`: Rust source and app modules.
- `static/`: static assets served by the app.
- `templates/`: Askama templates.
