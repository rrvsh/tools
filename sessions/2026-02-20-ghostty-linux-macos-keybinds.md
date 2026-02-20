# Ghostty Linux macOS-like Keybinds

Date: 2026-02-20
Task: Add Linux-only Home Manager Ghostty keybindings that mimic macOS defaults for tab/split management, clipboard actions, and text navigation/editing.

## Work Breakdown

1. Reviewed project Nix conventions in `.agents/skills/nix/SKILL.md`.
2. Located existing Ghostty module in `nix/modules/ghostty.nix`.
3. Retrieved Ghostty keybinding docs and action reference from ghostty.org to verify syntax and action names.
4. Added Linux-gated keybindings under `programs.ghostty.settings` using `lib.mkIf pkgs.stdenv.isLinux`.

## Decisions and Reasoning

- Kept configuration in the existing Ghostty Home Manager module to preserve one-file responsibility.
- Scoped keybindings to Linux only so Darwin behavior remains native/unmodified.
- Used `cmd` modifier in bindings to mirror macOS muscle memory on Linux (mapped to Super).
- Included tab traversal mappings (`cmd+shift+[`, `cmd+shift+]`) alongside tab creation/close.
- Used terminal-safe escape/control sequences for word and line navigation/editing:
  - `alt+left/right` -> `esc:b` / `esc:f`
  - `cmd+left/right` -> `Ctrl-A` / `Ctrl-E`
  - `alt+backspace`, `cmd+backspace`, `cmd+delete` for common shell text edits.

## Notes

- Existing package gating (`package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty`) remains unchanged.
- Added concise documentation at `docs/ghostty.md`.
- No formatting/lint/test command run in this step.
