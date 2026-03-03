## Task

Audit assertions in `sessions/2026-03-01-use-cases.md` and evaluate whether each claim can be proven using retrieval-led reasoning from the repository (and web only if required).

## Work breakdown

1. Read target use-cases file and identified two major scopes:
   - Core Nix/platform table (lines 5-77)
   - Additional app/CI/infra table (lines 82-109)
2. Launched two parallel `explore` subagents to maximize coverage and keep retrieval-led verification explicit.
3. Required each subagent to:
   - Extract distinct claims (splitting multi-claim rows where necessary)
   - Assign verdicts (`Proven`, `Partially Proven`, `Inconclusive`, `Contradicted`)
   - Attach concrete evidence with file+line references
4. Collated both outputs into a single verdict set and prepared user-facing synthesis.

## Reasoning and decisions

- Chose parallel subagent execution because the two table sections are independent.
- Preferred repository evidence over web lookups because claims are mostly implementation/state claims tied to this repo.
- Accepted two claims as partially proven where wording exceeded what code directly guarantees.

## Results snapshot

- Total claims audited: 99
- Proven: 97
- Partially proven: 2
- Inconclusive: 0
- Contradicted: 0

Partially proven claims:
- Line 98 (`scripts/tofu-plan-head.sh`): script clearly emits clean-ref `head.json`; production of `current.json` is not done by the script itself.
- Line 106 (`fooc` + Neovim bindings): both capabilities exist, but bindings are not directly wired to call `fooc`.

## Learning points

- The use-case sheet is highly aligned with actual Nix module structure and workflow wiring.
- Most claims are implementation-precise and directly auditable from module boundaries.

## Issues encountered and resolution

- No blocking issues.
- Scope size was large, so claim coverage was handled with subagent partitioning and explicit evidence requirements.

## Follow-up edits

- Removed `scripts/tofu-plan-head.sh` from the repository per user request.
- Removed the use-case row that referenced that script from `sessions/2026-03-01-use-cases.md`.
- Reworded the fuzzy note create/open use case to describe an integrated workflow system and explicitly linked both outputs: `scripts/fuzzy-open-or-create.sh` and `nvim/rafiq.lua`.

## Re-audit after edits

- Re-ran the assertion audit with two retrieval-led subagents (first and second table scopes).
- Updated claim totals after removal of the tofu-plan row:
  - Total claims audited: 98
  - Proven: 95
  - Partially proven: 3
  - Inconclusive: 0
  - Contradicted: 0

Partially proven in re-audit:
- Line 85 (`Add/edit markdown articles ...`): frontmatter parsing + content wiring are proven; user editing behavior is implied rather than directly enforced.
- Line 104 (`Keep ... environment reproducible ...`): declarative HM modules are present; reproducibility as an outcome is not directly proven from static config alone.
- Line 105 (integrated fuzzy-notes workflow system): both linked outputs exist and support note flows; direct coupling between script and Neovim logic is limited.

## Assertion audit standard (what good looks like)

- Define scope first (exact file, line window, and whether duplicated claims should be deduplicated).
- Normalize claims into atomic assertions (split rows that bundle multiple predicates).
- Use retrieval-led evidence only: repository source first, web lookup only when required by external behavior claims.
- Require file+line citations for every verdict; no uncited conclusions.
- Use a strict verdict model:
  - `Proven`: direct evidence matches claim wording.
  - `Partially Proven`: some predicates proven, some inferred or overstated.
  - `Inconclusive`: evidence is insufficient or absent.
  - `Contradicted`: repository evidence conflicts with claim.
- Distinguish implementation facts from outcome claims (for example, "module is configured" vs "behavior is guaranteed").
- Publish totals and coverage note (claims audited by verdict count).

## Follow-up proposal standard

- For every non-`Proven` item, include one concrete remediation option:
  - `Reword claim` to match existing implementation.
  - `Add missing implementation` to satisfy current claim text.
  - `Drop stale claim` if feature is intentionally removed.
- Include impact and effort estimate per item (small wording tweak vs multi-file implementation).
- Prefer scope columns that reference systems/projects rather than single outputs when behavior spans multiple components.
- Keep links explicit to all contributing outputs when using system-level wording.

## Fix-up round + re-run protocol

1. Apply agreed documentation/code changes.
2. Remove stale artifacts (scripts/rows/docs) that no longer apply.
3. Re-audit the exact updated line range, not the old one.
4. Recompute totals and compare against prior audit; call out deltas only.
5. Update session notes with:
   - What changed
   - New verdict totals
   - Remaining partial/inconclusive/contradicted items
6. If any partials remain, propose next fix-up actions in descending impact.
