---
name: zmx
description: Manage ZMX sessions. Use this when asked to kill yourself or the session.
---

# ZMX

`zmx` is the session manager I use.
You are not allowed to run any `zmx` commands unless explicitly instructed to.
Use `tmux` for anything requiring multiplexing or session management.

## Kill the current session and its containing shell

This is used when ending off a thread or `zmx` session.
This could be conditional e.g. after a task is complete.
Run `scripts/kill-current.sh` relative to this skill directory.
