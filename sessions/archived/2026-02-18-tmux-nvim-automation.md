# Session: tmux-driven Neovim TUI automation experiment

## Task

Validate whether we can run Neovim inside tmux and drive it non-interactively (send keys, capture pane output) in a way usable by a CLI agent.

## Work breakdown

- Entered a temporary Nix shell with both `tmux` and `neovim` available.
- Started a detached tmux session running `nvim -u NONE`.
- Sent ex commands and normal-mode keys with `tmux send-keys`.
- Captured terminal contents with `tmux capture-pane -p`.
- Persisted and inspected buffer output by writing to `/tmp/nvexp.txt`.

## Experiment command

Ran this end-to-end flow in one shell invocation:

- `nix shell nixpkgs#tmux nixpkgs#neovim --command bash -lc '...tmux new-session...tmux send-keys...tmux capture-pane...'`

Key actions inside Neovim:

- Mapped `Ctrl-y` to append `CTRL-Y`.
- Mapped `Alt-Enter` (`<M-CR>`) to append `ALT-ENTER`.
- Inserted base line `BASE`.
- Sent `C-y` and `M-Enter` via tmux.
- Wrote file to `/tmp/nvexp.txt`.

## Findings

- tmux automation works for Neovim TUI in a detached session.
- `tmux send-keys` successfully drove:
  - literal text,
  - control keys (`C-y`),
  - meta key (`M-Enter`) in this environment.
- `tmux capture-pane -p` returned useful verification output from the Neovim screen.
- File verification confirmed key handling:
  - `/tmp/nvexp.txt` contained:
    - `BASE`
    - `CTRL-Y`
    - `ALT-ENTER`

## Practical implications for agent testing

- This is viable for black-box E2E checks of Neovim keymaps and workflows.
- A robust pattern is:
  - start detached tmux session,
  - send deterministic key sequence,
  - capture pane for human-readable trace,
  - assert filesystem side effects (created/edited files).
- For flaky terminal timing, add short sleeps between major steps or poll with repeated capture checks.

## Caveats

- Key encoding for Alt/Meta can vary by terminal/tmux setup; keep a fallback key (e.g., `Ctrl-y`) in tested workflows.
- Running with full user config/plugins can introduce startup timing and dependency variability; `-u NONE` is best for control experiments.

## Learning

`tmux + send-keys + capture-pane` is sufficient as a Playwright-like terminal harness for Neovim TUI behavior, including modifier key paths, when tests are scripted with deterministic waits and file-based assertions.
