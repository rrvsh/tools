# Memory health audit

`memory-health-audit` reads `~/Agents/memory` and `~/Agents/MEMORY.md`.
It writes Markdown and JSON reports to `~/Agents/research/memory-audit/`.

Nemesis runs the command each week. Run it on demand with:

```console
memory-health-audit --offline
```

The deterministic audit checks:

- local Markdown references and index targets
- duplicate index entries and exact file copies
- Syncthing conflict copy names
- old dates on TODO lines
- GitHub pull request references
- secret-like patterns
- structural placement candidates
- the memory tree hash before and after the audit

The scheduled service runs offline. Offline reports mark pull request states as `unknown`.
Use `--github-state-file` with a local JSON object for deterministic state checks.
`--github-online` is an explicit opt-in. It sends only the repository name and pull request number to GitHub.

Reports contain paths, line numbers, dates, states, categories, and hashes.
They do not contain matched prose. Secret-like values always appear as `[REDACTED]`.
The report directory uses mode `0700`. Report files use mode `0600`.

Version one has no semantic Pi step.
It does not edit memory, create notifications, or change GitHub state.
