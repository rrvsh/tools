# Rust Web Server Guidelines

## Checks and Tests

```bash
just check-rs    # Run clippy and fmt checks
just test-rs     # Run cargo tests
```

Run a single test:
```bash
cargo test --manifest-path rs/Cargo.toml <test_name>
# Example: cargo test --manifest-path rs/Cargo.toml document_success
```

## Code Style

Formatting: Uses default `cargo fmt`.

Clippy: All lint groups are set to `deny` in `rs/site/Cargo.toml`:
- correctness, suspicious, complexity, perf, style, pedantic, cargo, nursery

Imports: Group imports by crate, use full paths for clarity:
```rust
use std::sync::Arc;
use crate::app::models::document::Document;
use crate::app::views::{ArticleLink, MonthGroup};
```

Naming:
- Types: `PascalCase` (e.g., `AppState`, `ArticleTemplate`)
- Functions/methods: `snake_case` (e.g., `load_documents_from_dir`)
- Modules: `snake_case` (e.g., `mod controllers`)
- Public API uses explicit `pub`; internal modules are private

Error Handling:
- Use `Result` types with `?` operator
- Use `ok()`, `ok_or()`, `unwrap_or()` for fallible operations
- Use `StatusCode` for HTTP error responses in axum handlers

State Management: Use `Arc<T>` for shared state across async handlers.

Tests: Inline tests in module files using `#[cfg(test)] mod tests { ... }`.

## Development

```bash
just watch-site     # Auto-rebuild site on changes
just watch-clippy   # Auto-clippy on changes
```

## Architecture

- **Framework**: Axum 0.8 + Askama 0.15 (Rust templates)
- **Routing**: `/` for index, `/{year}/{month}/{day}/{slug}` for articles
- **Static assets**: `/static` and `/assets` served via tower-http
- **Content**: Markdown files with YAML frontmatter parsed by `markdown-frontmatter`

### Settings (Environment Variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Bind address |
| `PORT` | `8080` | Bind port |
| `SITE_CONTENT_DIR` | `/Users/rafiq/publish` | Markdown articles directory |
| `STATIC_DIR` | `{crate}/static` | Static files directory |

### Content Format

Articles are Markdown files with YAML frontmatter:
```yaml
---
title: My Article
slug: my-article
date: 2026-03-29
---
Article content here.
```

### Key Types

- `AppState`: Shared state with `Arc`, contains `months` and `articles_by_key`
- `MonthGroup`: Groups articles by year/month for index page
- `ArticleLink`: Link representation of a document
- `format_article_date()`: Formats date as "Monday, the 1st of March 2026"
