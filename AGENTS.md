# AGENTS.md

## Instructions from User

This file is for both the user and the agent to edit.
When the user tells you to remember something, add it to this file.
You may add to this file anything that you think you should remember in the future.

### Things to remember

- Always use retrieval-led reasoning either via codebase exploration or web search. Never rely on training data.
    - Refer to `.agents/skills/web-search/SKILL.md` for web search instructions.
- Refer to `.agents/skills/git/SKILL.md` for instructions on committing and working with the remotes.
- Refer to `.agents/skills/just/SKILL.md` for instructions for running formatting, linting, or other checks and testing.
- Refer to `.agents/skills/nix/SKILL.md` for instructions on the `nix/` folder structure and project conventions.
- Refer to `.agents/skills/session-management/SKILL.md` for instructions on managing and processing session notes.
- Refer to `.agents/skills/opencode-docs-index/SKILL.md` for comprehensive documentation on Opencode docs.
- For tmux orchestration patterns for CLI-agent E2E runs, use `.agents/skills/tmux-e2e-cli-agent/SKILL.md`.

## Instructions from Agent

### Session Files

Always maintain a session file for the current task. Session files:
- Go in `sessions/` directory
- Use format: `YYYY-MM-DD-<task-name>.md`
- Contain: detailed breakdown of work, reasoning/decisions made, learning points discovered, bugs encountered and solutions
- Update existing session files for ongoing work; create new ones for new tasks
