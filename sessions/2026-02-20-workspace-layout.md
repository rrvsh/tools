# Task

Implement a tmux workspace launcher that enforces a process-note-plus-app workflow and supports a two-pane layout.

## Work Performed

1. Reviewed existing note tooling and conventions:
   - `scripts/process.sh`
   - `nvim/rafiq.lua`
   - `nix/modules/aliases.nix`
   - `AGENTS.md`
2. Added user memory requirements to `AGENTS.md`:
   - Always keep a process note open as an engineering notebook.
   - Deploy workspaces as process note + app context.
3. Added `scripts/workspace.sh`:
   - Creates/opens a dated process note: `YYYY-MM-DD-<task-slug>.md`
   - Creates/reuses tmux session: `ws-<task-slug>`
   - Left pane: opens note in Neovim
   - Right pane: shell in app directory
   - Layout default: right pane 70% (left pane 30%)
   - Supports override via `WORKSPACE_RIGHT_PANE_PERCENT`
4. Wired command into Home Manager package aliases:
   - Added `workspace` binary package from `scripts/workspace.sh`
   - Added alias `ws="workspace"`
5. Documented command in `README.md` day-to-day section.

## Decisions

- Use tmux split percentage from right pane (`-p 70`) to satisfy requested 30/70 layout.
- Use one session per task slug to make re-attachment deterministic.
- Keep note path under existing process notes directory for continuity with current workflow.

## Learning

- A small launcher script can enforce the process-note-first habit without changing Neovim keymaps.
- tmux session reuse makes iterative task sessions easier and avoids duplicate panes.

## Verification

- Ran `just check` successfully.
- Noted a Nix flake gotcha during first run: untracked files are not visible via flake source paths. The first check failed because `scripts/workspace.sh` was untracked; after staging the file, checks passed.
