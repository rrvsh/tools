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

## Additional Follow-up

- Added a dedicated alias for the same workflow in the pedia repo path:
  - `pedia = "process \"$HOME/1_repos/pedia\""` in `nix/modules/aliases.nix`.
- This reuses the existing `process` command behavior (file/content search, Enter open, Alt-Enter create markdown), but scopes it to `$HOME/1_repos/pedia` by default when using `pedia`.
- Added note convenience aliases in `nix/modules/aliases.nix`:
  - `day = "v ~/0_library/notes/daily/$(date +%F).md"`
  - `month = "v ~/0_library/notes/monthly/$(date +%Y-%m).md"`

## Neovim Keymaps Follow-up

- Added Neovim keymaps in `nvim/rafiq.lua` to mirror the new alias workflows:
  - `<leader>nd` opens/creates the daily note for today at `~/0_library/notes/daily/YYYY-MM-DD.md`.
  - `<leader>nm` opens/creates the monthly note at `~/0_library/notes/monthly/YYYY-MM.md`.
  - `<leader>np` opens the `process` picker in a terminal split.
  - `<leader>nP` opens the `process` picker scoped to `~/1_repos/pedia`.
- Added small helpers:
  - `edit_note(path)` ensures parent directories exist before opening.
  - `run_process(dir)` centralizes terminal command execution for process/pedia keymaps.

## EPUB Input Fix Follow-up

- Investigated failing `just check` for missing `epub-nvim` flake input used by `nix/modules/neovim.nix`.
- Confirmed upstream plugin source via GitHub (`CrystalDime/epub.nvim`).
- Added missing flake input in `flake.nix` as a non-flake source:
  - `epub-nvim = { url = "github:CrystalDime/epub.nvim"; flake = false; };`
- Updated lockfile with `nix flake lock --update-input epub-nvim`, which added pinned commit and nar hash.
- Re-ran `just check`; full check suite passed.

## EPUB Activation Follow-up

- Looked up upstream `epub.nvim` README and confirmed explicit activation is done with `require("epub").setup(opts)`.
- Updated `nvim/rafiq.lua` to initialize the plugin at startup:
  - `local epub = require("epub")`
  - `epub.setup({ auto_open = true })`
- Switched the EPUB open keymap to reuse the initialized module (`epub.open_epub(path)`) instead of requiring inline.

## FFF Process/Pedia Keymaps Follow-up

- Looked up `fff.nvim` upstream usage and confirmed `require("fff").find_files_in_dir(path)` is the right API for directory-scoped pickers.
- Updated Neovim keymaps in `nvim/rafiq.lua`:
  - `<leader>np` now opens FFF in `~/0_library/notes/process`.
  - `<leader>nP` now opens FFF in `~/1_repos/pedia`.
- Removed the old `run_process` terminal helper since these keymaps no longer shell out to `process`.
- Re-ran `just check`; full check suite passed.

## Process/Pedia Create-If-Missing Follow-up

- Added `browse_or_create_note(dir, prompt)` in `nvim/rafiq.lua` to preserve create-on-demand behavior in Lua:
  - prompts for a note name,
  - opens FFF picker for the directory when input is empty,
  - otherwise opens/creates `<input>.md` under the target directory.
- Updated `edit_note(path)` to ensure files are created on disk when missing (`writefile({}, path)`), not just opened as unsaved buffers.
- Updated keymaps:
  - `<leader>np` now uses `browse_or_create_note("~/0_library/notes/process", "Process")`.
  - `<leader>nP` now uses `browse_or_create_note("~/1_repos/pedia", "Pedia")`.
- Re-ran `just check`; full check suite passed.

## In-Picker Create Keybind Follow-up

- Requirement clarified: creation should happen from inside the FFF picker via a keybind (matching `process.sh` UX), not via pre-picker prompt.
- Checked `fff.nvim` source and found no built-in "create from query" action in picker keymaps; used picker internals to implement this safely.
- Replaced prompt flow with in-picker workflow in `nvim/rafiq.lua`:
  - Added `open_note_picker(dir)` to set active note directory context and open `find_files_in_dir`.
  - Added `create_note_from_picker_query()` that reads current picker query from `require("fff.picker_ui").state.query`, closes picker, and opens/creates `<query>.md` in active note dir.
  - Added `FileType` autocmd for `fff_input` to bind create action in picker on:
    - `<M-CR>` (Alt+Enter, terminal-dependent)
    - `<C-y>` (reliable fallback)
  - Keeps standard Enter behavior for opening existing files untouched.
- Updated keymaps:
  - `<leader>np` -> `open_note_picker("~/0_library/notes/process")`
  - `<leader>nP` -> `open_note_picker("~/1_repos/pedia")`
- Re-ran `just check`; full check suite passed.
