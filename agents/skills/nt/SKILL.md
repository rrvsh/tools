---
name: nt
description: Read or update Rafiq's durable personal task list with nt.
---

# nt task tracking

`nt` is Rafiq's durable personal task tracker. Use its MCP task tools rather than editing the store files.

- Read tasks freely with `nt_status` and saved queries with `nt_view`.
- Search for an exact task through the `nt` MCP namespace's `nt_search` codemode tool.
- Create or change a task only when Rafiq explicitly asks, or when verified work was opened from an existing tracked task.
- Do not silently convert general conversation or incidental follow-ups into tasks.
- For `nt_add`, use a short verb-first title, put supporting detail in `body`, and always set `source` to `pi`.
- Set `project` to the repository or recognised work area when it is clear. Do not guess.
- Use stable task IDs returned by `nt_status` or `nt_search` for `nt_update`.
- Mark a task done only after its requested outcome has been verified.
- Never remove a task. Ask Rafiq to use the `nt` CLI if deletion is needed.
- Do not use `nt` for agent memory, rules, research notes, or session summaries.
