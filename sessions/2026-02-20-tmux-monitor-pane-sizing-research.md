## Task

Research whether tmux can read pane sizes in monitor pixels (not only terminal cells), and whether a dual-pane layout can enforce: left pane <= 1/3 of monitor and right pane hidden when terminal is too small.

## Retrieval-led workflow executed

1. Read local agent guidance files:
   - `.agents/skills/web-search/SKILL.md`
   - `.agents/skills/tmux-e2e-cli-agent/SKILL.md`
   - `.agents/skills/session-management/SKILL.md`
2. Ran `ddgr` web searches for tmux pane sizing, tmux format variables, and hide-pane patterns.
3. Fetched primary references:
   - `man7 tmux(1)` (captured in tool output)
   - `tmux wiki: Formats`
   - `xterm control sequences`
   - `terminalguide CSI 14 t` note
   - `OpenBSD tmux(1)` (secondary man source)
4. Used targeted retrieval (`grep`/`read`) against saved outputs to extract exact passages on:
   - pane/window/client size variables
   - cell pixel variables
   - `resize-pane`, `split-window`, `break-pane`, `join-pane`
   - `if-shell -F`, `%if`
   - hooks (`client-resized`, `window-resized`)
   - `window-size` behavior

## Key findings

### 1) What tmux can measure directly

- tmux directly exposes pane/window/client dimensions in terminal units (rows/columns), via format variables such as:
  - `pane_width`, `pane_height`
  - `window_width`, `window_height`
  - `client_width`, `client_height`
- tmux also exposes per-cell pixel size:
  - `client_cell_width`, `client_cell_height`
  - `window_cell_width`, `window_cell_height`
- This means tmux can compute pixel size of pane content area as roughly:
  - `pane_width * client_cell_width`
  - `pane_height * client_cell_height`

### 2) What tmux does not expose as a native concept

- No direct tmux format variable for monitor/work-area geometry was found.
- tmux model is client/window/pane inside a terminal, not OS monitor regions.
- Therefore, "left pane <= 1/3 of monitor" is not natively enforceable from tmux alone in a robust cross-terminal way.

### 3) Terminal-level escape sequences (outside tmux-native model)

- xterm XTWINOPS supports querying terminal/window/screen pixel sizes:
  - `CSI 14 t` family for text/window pixel sizes
  - `CSI 15 t` for screen pixels
  - `CSI 16 t` for cell pixel size
  - `CSI 18 t` and `CSI 19 t` for character dimensions
- TerminalGuide confirms `CSI 14 t` behavior in several emulators, but support is emulator-dependent.
- These are terminal emulator capabilities, not stable tmux abstractions.

### 4) Feasibility of requested layout behavior

- "Left pane <= 1/3" is straightforward in terminal/window units:
  - use `split-window -h -p 33` for initial split
  - use `resize-pane -x 33%` as needed
- "Hide right pane if too small" is feasible with tmux hooks and conditional formats:
  - hook on `client-resized` or `window-resized`
  - evaluate width threshold with `if-shell -F '#{<:#{window_width},N}' ...`
  - hide via `break-pane` (move pane to another window) and restore via `join-pane`
- This is reliable in terms of terminal columns, not monitor pixels.

## Reasoning/decision log

- Preferred tmux man page and tmux wiki over blog sources for canonical behavior.
- Kept StackExchange/blog links as optional context but did not base conclusions on them.
- Used xterm control-sequence docs to separate terminal-emulator capability from tmux-native capability.
- Concluded monitor-relative guarantees require external OS/window-manager info or terminal-specific protocols, which are brittle.

## Bugs/constraints encountered

- `tmux` binary is not installed in this environment, so no live command validation was possible.
- Some web pages (StackExchange direct fetch) returned HTTP 403.
- Worked around this by using man/wiki/ctlseq primary docs and local extracted tool outputs.

## Practical recommendation to user

- Build policy on `window_width` (columns), not monitor pixels.
- If monitor-relative behavior is mandatory, implement an external helper (WM/API aware) and feed computed thresholds into tmux user options; accept reduced portability.
