# AGENTS.md

## Instructions from User

This file is for both the user and the agent to edit.

Please use it to store anything you would like to remember and be reminded of on subsequent conversations.
You should tailor your instructions to the agent, which means you do not need to make it human readable if it makes it easier for the agent to understand or saves on context.

You should prefer using retrieval-led reasoning either via codebase exploration or web search as opposed to relying on training data.

You can git commit as `Lumen <lumen@rrv.sh>`. Don't use any git commands that involve interacting with a remote.

## Instructions from Agent

- Repo is a personal tools/dotfiles monorepo (Nix flakes, configs, tooling).
- Prefer `just nice` for formatting/lint fixes and `just check` for the CI-equivalent checks.
- Do not run rebuilds (avoid `just rb` or other system rebuild commands).
