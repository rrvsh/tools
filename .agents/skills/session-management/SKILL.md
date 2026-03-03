# Session Management

## Directory Structure

The `@sessions/` directory is organized as follows:

- `raw/` - Raw agent session exports (auto-generated)
- `archived/` - Session notes that have been processed and skill learnings extracted
- Root level files (*.md not in subfolders) - Unprocessed sessions pending review

## Cleanup Process

When instructed to "clean up sessions":

### 1. Identify Unprocessed Sessions

Find all `.md` files directly in `@sessions/` (not in subdirectories):
```bash
glob "sessions/*.md"
```

### 2. Spawn Subagents for Each Unprocessed Session

For each unprocessed session file, spawn a subagent to extract learning points:

```
Task(description="Extract learnings from session", prompt="""
Read the session file at /home/rafiq/1_repos/tools/sessions/<filename>.md

Extract the following from this session:
1. Key learnings - new techniques, patterns, or solutions discovered
2. Bugs encountered and their fixes
3. Important references or documentation links
4. Any "gotchas" or non-obvious behaviors noted
5. Project-specific conventions discovered

Return your findings in this format:

## Learnings
- <bullet points of key learnings>

## Bugs & Fixes
- <bug description>: <solution>

## References
- <link>: <why it matters>

## Conventions
- <convention>: <explanation>
""")
```

### 3. Update Skills

After subagents return their findings:

**For Existing Skills:**
- Read the relevant skill file from `.agents/skills/<skill-name>/SKILL.md`
- Append new learnings as bullet points
- Merge related points, avoiding duplicates

**For New Skills:**
- If the learning doesn't fit existing skills, create a new skill at `.agents/skills/<new-skill-name>/SKILL.md`
- Keep skills focused on a single domain/topic
- Follow the existing skill format (markdown bullet points)

### 4. Archive Processed Sessions

After extracting learnings and updating skills:
```bash
mv /home/rafiq/1_repos/tools/sessions/<filename>.md /home/rafiq/1_repos/tools/sessions/archived/
```

If `sessions/*.md` returns no files, cleanup is complete and no archive step is needed.

## Skill Naming Conventions

- Use kebab-case (e.g., `nix-package`, `rust-testing`)
- Be specific but not overly granular
- Examples of good skill names:
  - `nix-flakes` - Working with Nix flakes
  - `yazi-plugins` - Yazi plugin development
  - `git-worktree` - Git worktree operations
  - `web-search` - Effective web search techniques

## Example Learning Extraction

**From session file:**
```
### Bug 1: Wrong Keymap Section Name
Used `manager.prepend_keymap` instead of `mgr.prepend_keymap`. 
Home-manager's yazi module uses abbreviated section names.
```

**Added to skill** (`.agents/skills/nix/SKILL.md`):
```
- When configuring yazi in home-manager, use abbreviated section names (e.g., `mgr.prepend_keymap` not `manager.prepend_keymap`)
```
