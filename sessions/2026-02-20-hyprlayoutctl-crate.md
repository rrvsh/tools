## Task

Implement `hyprlayoutctl` Rust crate with CLI, layout discovery/resolution, layout engine, Hyprland IPC adapter, watch mode debounce behavior, and thorough tests.

## Work Log

- Added a new workspace member crate at `rs/hyprlayoutctl` and wired it into `rs/Cargo.toml`.
- Implemented the CLI with subcommands: `apply`, `watch`, `list`, and `validate`.
- Implemented global flags: `--config`, repeatable `--layout-dir`, `--dry-run`, and `--verbose`.
- Added config parsing for inline layouts in `config.toml` and standalone `*.layout` files.
- Implemented layout resolution with path-first lookup and ambiguity detection.
- Implemented deterministic pane assignment and arrangement (`single` + `grid` with preference support).
- Implemented Hyprland runtime via `hyprctl` JSON/dispatch and event-socket subscription.
- Implemented debounced watch re-apply behavior for workspace/window events.
- Added extensive unit tests across parsing, resolution, planning/idempotence expectations, debounce behavior, and app flow.

## Decisions and Reasoning

- Chose an internal engine plan model (`Plan`, `HyprCommand`) to separate pure planning logic from side-effecting Hypr IPC.
- Chose path-first layout resolution exactly per spec, then searched inline/file-discovered layouts by key/name/stem.
- Ensured idempotence by only emitting move/resize/floating commands when current client state differs from desired state.
- Used scoped clients only (focused monitor + active workspace) in v1.
- Kept v1 floating-only and no-overlap validation.

## Bugs Encountered and Fixes

- Strict clippy profile failures (`missing_errors_doc`, cast lints, `items_after_test_module`, etc.) blocked `just check`:
  - Added targeted rustdoc `# Errors` docs on public `Result` APIs.
  - Added focused `#[allow(...)]` only for unavoidable float/int conversion and one style placement lint.
  - Fixed one nursery lint by replacing `unwrap_or(...)` with `unwrap_or_else(...)`.
- Engine test expectation mismatch for spawn behavior:
  - Updated spawn resolution so `camera` is treated as non-spawnable alias and `pick_one` selects the first spawnable token.
- Debounce test flakiness due coarse poll interval and disconnect timing:
  - Reduced watch-loop poll interval to `min(25ms, debounce)`.
  - Ensured pending changes flush once on channel disconnect.

## Learning Points

- Modeling assignment and arrangement as pure functions makes watch-mode re-application and testing straightforward.
- Re-running client discovery after spawn is required to make ensure/ensure_min behavior visible in the same apply cycle.

## Validation Checklist

- Completed: `just nice`
- Completed: `just check`
- Completed: `cargo test --manifest-path rs/Cargo.toml -p hyprlayoutctl`
