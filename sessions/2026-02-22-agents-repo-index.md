# 2026-02-22-agents-repo-index

## Scope

Create cohesive `AGENTS.md` files across the entire repository, one per directory, so the folder tree is self-documenting for agent workflows.

## Steps Taken

1. Enumerated tracked files and derived tracked directory coverage.
2. Reviewed root instructions and repository conventions (`AGENTS.md`, `README.md`, `Justfile`, skill files).
3. Drafted a complete per-directory AGENTS plan covering all tracked directories and intermediate parents.
4. Updated root `AGENTS.md` to keep it as canonical root policy with session lifecycle and hardcoded skills index.
5. Added `AGENTS.md` files to each directory in the repository tree.

## Decisions

- Kept each local `AGENTS.md` concise and operational: scope, key files, rules, and subtree index when relevant.
- Avoided over-prescriptive duplication of root policy; local files focus on directory-specific usage.
- Included intermediate directories (`.agents/`, `.agents/skills/`, `.github/`) so coverage is complete.

## Bugs Encountered

- None.

## Follow-up Ideas

- Run a periodic docs check that verifies every directory still has `AGENTS.md`.
- Add a script to regenerate or validate subtree indexes from `git ls-files`.
