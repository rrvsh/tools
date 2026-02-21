## Task
- Produce an architectural design record for a minimal from-scratch Rust menu bar app.
- Compare alternatives for each architecture component and select a best-total stack.
- Write ADR under `docs/adr/` including problem statement, alternatives, design, implementation plan, testing, and security/performance implications.

## Work Breakdown
- Reviewed repository structure and documentation folders to place the ADR in the right location.
- Retrieved upstream crate documentation (docs.rs) for key candidate components (`tray-icon`, `tao`, `chrono`, `tokio`) to ground trade-off analysis.
- Created `docs/adr/0001-minimal-rust-menubar-time-state.md` with component-by-component alternatives and decisions.
- Included explicit architecture composition, domain model, boundary semantics, implementation phases, and test strategy.
- Updated ADR scope to NixOS-only after follow-up request.
- Reviewed actual Hyprland setup in `nix/modules/hyprland.nix` and host wiring in `nix/configs/nemesis.nix` to anchor decisions to repository reality.
- Reworked architecture from cross-platform tray app to Hyprland-native Waybar integration with a minimal Rust provider crate.
- Implemented initial Waybar configuration in `nix/modules/hyprland.nix` with an otherwise empty bar and a single right-aligned clock module.
- Added minimal Waybar CSS in `nix/modules/hyprland.nix` to keep the bar/clock transparent and render clock text as white with no extra module styling.

## Decisions
- Scope is NixOS + Hyprland only (no Linux/Windows cross-platform requirements).
- Choose Waybar custom module as bar surface.
- Choose minimal Rust binary as data provider (not full bar renderer).
- Choose `chrono` for local-time handling and formatting.
- Choose 30s Waybar polling interval for v1 simplicity.
- Choose data-driven in-memory rules + TOML config rendered by Home Manager.
- For the immediate requested state, defer custom module wiring and provide only one clock module formatted as `Weekday, DD/MM/YYYY HH:MM:SS` with 1-second updates.

## Learnings
- Current Hyprland module config has monitor/input/binds but no existing bar configuration.
- `nix/configs/nemesis.nix` already imports the Hyprland module, so bar integration should be implemented in existing module path.
- NixOS-only scope materially simplifies architecture and removes need for tray/event-loop portability abstractions.
- A minimal Waybar setup in Home Manager is straightforward: empty left/center arrays and `modules-right = [ "clock" ]` is sufficient for right alignment.

## Bugs Encountered
- `crates.io` pages were JavaScript-only for this environment; switched to docs.rs sources for retrieval-backed analysis.
