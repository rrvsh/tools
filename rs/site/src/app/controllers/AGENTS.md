# AGENTS.md

## Scope

HTTP route modules and handlers.

## File Index

- `mod.rs`: route registration and shared controller wiring.
- `index.rs`: homepage/index handlers.
- `article.rs`: article detail handlers.

## Rules

- Keep handlers thin and delegate parsing/formatting to models/views.
- Keep response/template contracts explicit and stable.
