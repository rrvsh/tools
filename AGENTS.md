# AGENTS.md

## Role

This is the root instruction file for the entire repository.
It is co-maintained by the user and the agent.
When the user says to remember something, add it here (or in the most local `AGENTS.md` when scope is clearly local).

## Core Operating Rules

- Always use retrieval-led reasoning through codebase exploration and, when needed, web search.
- Never rely on training memory when repository or web evidence is available.
- Keep changes cohesive with local directory conventions and architecture.
- Do not perform git remote operations unless explicitly requested by the user.

## Session Lifecycle (Always Active)

- Maintain a session note for each substantive task in `sessions/`.
- Use `YYYY-MM-DD-<task-name>.md` naming.
- Keep the active note updated throughout the task lifecycle.
- Include: scope, steps taken, decisions made, bugs encountered, fixes, and follow-up ideas.
- Session structure:
  - `sessions/*.md`: active or unprocessed notes
  - `sessions/archived/*.md`: processed historical notes
  - `sessions/raw/*.md`: raw exported transcripts

## Skills Index (Hardcoded)

- `.agents/skills/git/SKILL.md`
- `.agents/skills/just/SKILL.md`
- `.agents/skills/neovim-automation/SKILL.md`
- `.agents/skills/nix/SKILL.md`
- `.agents/skills/opencode-docs-index/SKILL.md`
- `.agents/skills/session-management/SKILL.md`
- `.agents/skills/tmux-e2e-cli-agent/SKILL.md`
- `.agents/skills/web-search/SKILL.md`

## Repository Mental Model

- `.agents/`: reusable agent skill playbooks.
- `.github/workflows/`: CI, docs checks, build-and-deploy automation.
- `docs/`: runbook and cheatsheet notes.
- `nix/`: flake module architecture (`configs`, `modules`, `outputs`).
- `nvim/`: Neovim runtime config source.
- `rs/`: Rust workspace, including the `site` web app.
- `scripts/`: helper scripts for checks and local flows.
- `sessions/`: active memory and archived task notes.
- `sops/`: encrypted secret files and usage notes.
- `tf/`: Terraform/OpenTofu infrastructure definitions.

## Local AGENTS Policy

- Every directory in this repository has its own `AGENTS.md`.
- On entry to a directory, read its local `AGENTS.md` and follow its scope-specific rules.
- If instructions conflict, priority is:
  1. Explicit user instruction
  2. Nearest local `AGENTS.md`
  3. This root `AGENTS.md`
