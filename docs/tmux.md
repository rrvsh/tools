# tmux

## keybinds (no prefix)

- `Ctrl+w`: close current pane
- `Ctrl+d`: split pane to the right
- `Ctrl+Shift+d`: split pane downward
- `Ctrl+h/j/k/l`: move focus left/down/up/right
- `Ctrl+Shift+h/j/k/l`: resize pane left/down/up/right
- `Ctrl+Tab`: next tmux window
- `Ctrl+Shift+Tab`: previous tmux window

## notes

- Keybinds are configured in `nix/modules/tmux.nix` via Home Manager `programs.tmux.extraConfig`.
- Split operations keep the same working directory as the active pane.
- `Ctrl+Shift+...` keybinds require terminal support for extended key reporting.
