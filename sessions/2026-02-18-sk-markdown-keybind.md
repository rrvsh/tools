## Task

Investigate whether `sk` can support a workflow that:
- searches/open existing files in a target folder, and
- on a custom keybind, creates a markdown file named from the current query.

## Work Performed

1. Checked current alias implementation in `nix/modules/aliases.nix`:
   - `e` currently runs `sk` and opens selected output in `$EDITOR`.
2. Queried local CLI docs:
   - Ran `sk --help`.
   - Exported and inspected `sk --man` keybind/action docs.
3. Verified relevant capabilities from docs:
   - Custom binds via `--bind`.
   - Action chaining with `+`.
   - `execute(...)` / `execute-silent(...)` for shell commands.
   - Conditional actions with `if-query-empty(...)` / `if-query-not-empty(...)`.
   - Placeholder expansion in bind commands, including `{q}` for current query.
   - `accept(...)` can print an explicit argument when triggered.

## Decision / Conclusion

This workflow is supported by `sk` natively via custom keybind actions.

Practical pattern:
- Default Enter keeps normal fuzzy-find behavior.
- Custom keybind runs `touch <dir>/{q}.md` and then `accept(<dir>/{q}.md)` so caller can open it in `$EDITOR`.

## Notes / Edge Cases

- Empty query should be guarded (e.g. `if-query-not-empty(...)`) to avoid creating `.md`.
- Query text can contain spaces/special chars; consider sanitizing if strict filename style is preferred.
- If listing is static, reloading the file list after creation is optional because the accepted path can be returned directly.

## Learning

`sk` keybind actions are expressive enough to emulate "create-on-hotkey, otherwise select existing" workflows without external UI glue, beyond a small shell wrapper for open-in-editor behavior.

## Follow-up Change

- Refactored the inline fish alias implementation into a dedicated script: `scripts/process.sh`.
- Promoted `process` to a Home Manager package in `nix/modules/aliases.nix`:
  - `process-bin = pkgs.writeShellScriptBin "process" (lib.fileContents (cfg.paths.root + "/scripts/process.sh"));`
  - `home.packages = [ process-bin ];`
  - removed the `process` shell alias (command now comes from PATH package)
- Behavior remains:
  - `process [dir]` lists files under `dir` (default `$HOME/0_library/notes/process`) via `find ... | sk`.
  - `Enter` opens selected file in `$EDITOR` (falls back to `nvim` if unset).
  - `Alt-Enter` creates `<dir>/<query>.md` (including parent dirs if needed) and opens it.

## Latest Update

- Updated `scripts/process.sh` default directory to `$HOME/0_library/notes/process`.
- Extended candidate source for `sk` to include both:
  - file paths (`find` output) for filename search,
  - file content lines (`rg --line-number ... "."`) for content search.
- Added handling for content-line selections (`path:line:text`) to open editor at the matched line (`$EDITOR +line path`).
- Added `mkdir -p "$dir"` so default path exists automatically.
- Added explicit `sk` bind for normal enter behavior: `enter:accept` alongside `alt-enter:accept(__CREATE_MD__)`.

## Notes

- `nix/modules/aliases.nix` now follows the project convention `let cfg = config.flake;` so root paths are referenced through `cfg.paths.root`.
