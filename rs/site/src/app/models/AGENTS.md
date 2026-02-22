# AGENTS.md

## Scope

Domain model and content ingestion logic.

## File Index

- `mod.rs`: model module exports.
- `document.rs`: markdown/frontmatter loading and parsing.

## Rules

- Keep file IO and parsing deterministic.
- Keep test coverage near parsing behavior and edge cases.
