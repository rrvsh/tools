# Task

Add tmux root keybindings (no prefix) for pane/window management.

## Requirements

- `Ctrl+w`: close pane
- `Ctrl+d`: split right
- `Ctrl+Shift+d`: split down
- `Ctrl+h/j/k/l`: move between panes
- `Ctrl+Shift+h/j/k/l`: resize pane left/down/up/right
- `Ctrl+Tab`: move between windows
- `Ctrl+Shift+Tab`: reverse window cycling

## Work Performed

1. Searched repo for existing tmux config and found none.
2. Added `nix/modules/tmux.nix` with Home Manager `programs.tmux.enable = true`.
3. Added root (`-n`) keybindings implementing requested controls.
4. Enabled `extended-keys` in tmux config to improve support for `Ctrl+Shift+<key>` combinations.
5. Added reverse tab cycling with `Ctrl+Shift+Tab` mapped to previous window.
6. Documented tmux keybinds in `docs/tmux.md`.

## Notes

- Split bindings preserve working directory using `-c "#{pane_current_path}"`.
- `Ctrl+Shift+...` handling depends on terminal support for extended key reporting.

## Verification

- Ran `just check` successfully.
