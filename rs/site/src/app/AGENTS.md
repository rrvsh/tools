# AGENTS.md

## Scope

Application composition layer and runtime state.

## File Index

- `mod.rs`: app startup and router construction.
- `settings.rs`: environment-driven settings.
- `state.rs`: shared app state and article index.

## Rules

- Keep routing and request handlers in `controllers/`.
- Keep filesystem/content parsing in `models/`.
- Keep display/grouping transformations in `views/`.

## Subtree Index

- `controllers/`: endpoint handlers and route modules.
- `models/`: domain/content model loading.
- `views/`: presentation model helpers.
