# Session: 2026-03-06-hyprland-automation-research

## Work Summary
- Goal: research runtime automation for Hyprland workspace and layout management.
- Scope constrained to official docs pages requested by user: Using hyprctl, IPC, Dispatchers, Binds.
- Main outputs: command families, state-query surfaces, socket2 event names, scripting patterns, and limits.

## Detailed Breakdown
- Retrieved source-of-truth docs from the official `hyprwm/hyprland-wiki` repository raw markdown pages that back the same wiki URLs.
- Extracted `hyprctl` control/query commands and flags (`dispatch`, `keyword`, info commands, `--batch`, `-j`, `-i`).
- Mapped dispatcher capabilities relevant to workspaces/windows/layout (workspace focus/move/swap, floating/fullscreen, grouping, submaps, custom events).
- Mapped IPC socket roles and critical operational details:
  - `.socket.sock` for hyprctl-like requests.
  - `.socket2.sock` for streaming events in `EVENT>>DATA` format.
- Enumerated workspace/window/layout-centric socket2 events and noted `v2` variants carrying IDs/addresses.
- Collected warnings/limits from docs (synchronous request handling, freeze risk on unclosed sockets, event caveats, keybind caveats).

## Reasoning and Decisions
- Used retrieval-only workflow to avoid memory-based assumptions.
- Preferred raw markdown docs over rendered wiki HTML due better fidelity and lower parsing ambiguity.
- Focused event list on automation-relevant signals while preserving exact event names.

## Learnings
- Hyprland exposes both control and event channels as UNIX sockets under `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/`.
- `hyprctl` and `.socket.sock` requests are synchronous; connection hygiene and batching are critical for responsive automation.
- Many workspace/window events have `v2` variants with richer machine-parseable IDs.

## Bugs Encountered and Solutions
- Bug: direct wiki fetch returned huge HTML and truncated output, making extraction noisy.
- Fix: switched to official wiki source repository markdown (`hyprwm/hyprland-wiki`) and consumed raw pages directly.
