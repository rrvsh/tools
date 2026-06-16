pi-agent
=======

pi-coding-agent is used as the CLI agent of choice. We use the package from pi.nix primarily to fix the SSE response timeout issue when using Codex, patched in 0.79.2.

Extensions
----------

`pi-mcp-adapter` is used for the Atlassian Cloud MCP on `auto`.
`pi-web-access` and `pi-subagents` are self-explanatory.
`pi-hermes-memory` is used for persisting memory via a global, user, and project-local context, along with semantic search across all conversations.
