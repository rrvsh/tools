# github-automation

This repository contains a central GitHub automation controller and an OpenCode proactive scan worker workflow.

## what it does

- Runs every day at 00:00 UTC via `.github/workflows/github-automation.yaml`.
- Applies PR hygiene rules to configured repositories:
  - rebases ready-for-review PRs that are behind the base branch.
- Dispatches proactive scan runs to configured repositories via `repository_dispatch` (`automation.scan`).
- Writes a JSON report (`automation-report.json`) and markdown summary (`automation-summary.md`) in each run.

## configuration

Repo rules are configured in `automation/repos.json`.

### defaults

- `skip_labels`: PR labels that opt a PR out of auto-rebase.
- `max_pr_updates_per_run`: upper bound for rebase operations in a single run.
- `scan_cooldown_days`: minimum days between proactive scans (based on latest `automation/proactive` PR).
- `agent_dispatch.event_type`: dispatch event type (default `automation.scan`).
- `agent_dispatch.open_pr_label`: label used to detect active proactive PRs.

### repo entries

Each entry in `repos` supports:

- `name`: `owner/repo`.
- `enabled`: whether to process the repository.
- `rules.auto_rebase_ready_prs`: enable PR branch rebasing.
- `rules.dispatch_agent_scan`: enable proactive scan dispatch.
- Optional overrides for defaults.

## secrets

- `AUTOMATION_GH_TOKEN`: recommended token for cross-repo automation from this controller workflow.
  - Should have access to each target repo.
  - Must be able to update PR branches and call `repository_dispatch`.
- `GITHUB_TOKEN` is used as fallback, but is typically scoped to the current repository.

For the worker workflow (`opencode-proactive-scan.yaml`) in each target repo:

- `ANTHROPIC_API_KEY` (or your chosen model provider key)

## rollout to other repos

1. Add the target repo to `automation/repos.json`.
2. Add/copy `.github/workflows/opencode-proactive-scan.yaml` into that repo.
3. Ensure the repo has required model API key secret.
4. Ensure controller token can dispatch to the target repo.

## local testing

Dry-run mode (safe, no mutations):

```bash
python3 scripts/github_automation.py \
  --config automation/repos.json \
  --output automation-report.json \
  --summary automation-summary.md \
  --dry-run
```

Unit tests:

```bash
python3 -m unittest scripts.tests.test_github_automation
```
