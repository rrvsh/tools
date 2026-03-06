# Playbook: Build a Documentation Index Skill

Use this playbook to create a reusable `SKILL.md` that helps an agent quickly navigate and retrieve answers from any documentation set.

## Goal

Produce a searchable documentation index with:
- concise keyword-oriented search terms,
- short page summaries,
- absolute links,
- and a repeatable link validation step.

## Inputs

- Documentation source root (site, docs folder, or both)
- Target skill path (for example, `.agents/skills/<skill-name>/SKILL.md`)
- Optional constraints (internal-only docs, auth, version pinning)

## Output Format

Use a markdown table in `SKILL.md`:

| Search terms | Key points | Link |
| --- | --- | --- |
| comma-separated query terms | one-line scope summary | absolute URL or repo path |

Keep each row focused on one page/topic.

## Workflow

1. Inventory sources
- Enumerate doc sections and canonical pages.
- Prefer stable landing pages over transient changelog/blog links.

2. Build topic map
- Group pages into major domains (for example: core, usage, configure, develop).
- Capture user-intent queries, not just page titles.

3. Draft index rows
- `Search terms`: 6-12 high-signal terms/synonyms users are likely to type.
- `Key points`: one sentence describing what decisions/tasks the page helps with.
- `Link`: canonical absolute URL (recommended) or stable repo path.

4. Normalize links
- Convert relative links to absolute HTTPS URLs when indexing public docs.
- Remove duplicates and redirect variants.

5. Add maintenance notes
- Include a short section at the end with rebuild and validation expectations.

6. Validate links
- Run a script or command that checks every indexed URL with `curl`.
- Treat non-2xx/3xx responses as failures and fix rows before finalizing.

## Quality Bar

- Coverage: all major doc domains represented
- Retrieval quality: search terms match real troubleshooting and setup queries
- Readability: key points are compact and task-oriented
- Durability: links are canonical and stable
- Verifiability: link checks are reproducible

## Suggested `SKILL.md` Skeleton

```md
# <Skill Name>

Search terms are suggestions for queries. Key points summarize what the page covers.
Always use subagents for research.

| Search terms | Key points | Link |
| --- | --- | --- |
| ... | ... | ... |

Maintenance notes:
- Keep links canonical and absolute where possible.
- Re-run link validation whenever the index is rebuilt.
```

## Link Checker Pattern

Recommended behavior for a checker script:
- Parse the table links from `SKILL.md`
- `curl -I` each URL with retry and timeout
- Report failures with row context
- Exit non-zero on any invalid link

## Practical Guidance

- Favor retrieval usefulness over exhaustive page descriptions.
- Keep terminology aligned with the docs, but include common aliases.
- If docs are versioned, include version in links or note target version explicitly.
- Rebuild the index when docs IA (information architecture) changes.

## Definition of Done

- `SKILL.md` exists with a complete table and maintenance notes.
- All links pass validation.
- The index can answer: install/setup, configuration, operations, troubleshooting, and extension/integration workflows for the target docs.
