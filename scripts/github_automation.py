#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


UTC = dt.timezone.utc


def utc_now() -> dt.datetime:
    return dt.datetime.now(tz=UTC)


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def has_label(labels: list[dict[str, Any]], name: str) -> bool:
    return any((label.get("name") == name for label in labels))


@dataclass
class CommandResult:
    returncode: int
    stdout: str
    stderr: str


class GhClient:
    def run(self, args: list[str], stdin: str | None = None) -> CommandResult:
        completed = subprocess.run(
            ["gh", *args],
            input=stdin,
            text=True,
            capture_output=True,
            check=False,
        )
        return CommandResult(
            returncode=completed.returncode,
            stdout=completed.stdout,
            stderr=completed.stderr,
        )

    def json(self, args: list[str], stdin: str | None = None) -> Any:
        result = self.run(args, stdin=stdin)
        if result.returncode != 0:
            raise RuntimeError(f"gh {' '.join(args)} failed: {result.stderr.strip()}")
        if not result.stdout.strip():
            return None
        return json.loads(result.stdout)


def evaluate_rebase_eligibility(
    pr: dict[str, Any],
    base_owner: str,
    skip_labels: list[str],
) -> tuple[bool, str]:
    if pr.get("isDraft", False):
        return False, "draft"
    if pr.get("mergeStateStatus") != "BEHIND":
        return False, f"merge_state_{pr.get('mergeStateStatus', 'unknown').lower()}"
    if any(has_label(pr.get("labels", []), label) for label in skip_labels):
        return False, "skip_label"

    owner = pr.get("headRepositoryOwner", {}) or {}
    head_owner = owner.get("login")
    if head_owner and head_owner != base_owner and not pr.get("maintainerCanModify", False):
        return False, "fork_no_maintainer_modify"

    return True, "eligible"


def build_repo_settings(defaults: dict[str, Any], repo_cfg: dict[str, Any]) -> dict[str, Any]:
    merged = {
        "skip_labels": list(defaults.get("skip_labels", [])),
        "max_pr_updates_per_run": int(defaults.get("max_pr_updates_per_run", 5)),
        "scan_cooldown_days": int(defaults.get("scan_cooldown_days", 7)),
        "agent_dispatch": dict(defaults.get("agent_dispatch", {})),
        "rules": {
            "auto_rebase_ready_prs": False,
            "dispatch_agent_scan": False,
        },
    }
    merged["rules"].update(repo_cfg.get("rules", {}))
    merged["skip_labels"] = repo_cfg.get("skip_labels", merged["skip_labels"])
    if "max_pr_updates_per_run" in repo_cfg:
        merged["max_pr_updates_per_run"] = int(repo_cfg["max_pr_updates_per_run"])
    if "scan_cooldown_days" in repo_cfg:
        merged["scan_cooldown_days"] = int(repo_cfg["scan_cooldown_days"])
    if "agent_dispatch" in repo_cfg:
        merged["agent_dispatch"].update(repo_cfg["agent_dispatch"])
    return merged


class Controller:
    def __init__(self, gh: Any, dry_run: bool) -> None:
        self.gh = gh
        self.dry_run = dry_run

    def run(self, config: dict[str, Any]) -> dict[str, Any]:
        defaults = config.get("defaults", {})
        repos = config.get("repos", [])
        started_at = utc_now()
        report: dict[str, Any] = {
            "started_at": started_at.isoformat(),
            "dry_run": self.dry_run,
            "repos": [],
            "totals": {
                "repos_processed": 0,
                "rebase_updated": 0,
                "rebase_failed": 0,
                "scan_dispatched": 0,
                "scan_failed": 0,
            },
        }

        for repo_cfg in repos:
            if not repo_cfg.get("enabled", True):
                continue

            repo_name = repo_cfg["name"]
            settings = build_repo_settings(defaults, repo_cfg)
            repo_result: dict[str, Any] = {
                "repo": repo_name,
                "auto_rebase": self._handle_rebases(repo_name, settings),
                "agent_dispatch": self._handle_dispatch(repo_name, settings),
            }

            report["totals"]["repos_processed"] += 1
            report["totals"]["rebase_updated"] += repo_result["auto_rebase"]["updated"]
            report["totals"]["rebase_failed"] += repo_result["auto_rebase"]["failed"]
            report["totals"]["scan_dispatched"] += int(repo_result["agent_dispatch"]["dispatched"])
            report["totals"]["scan_failed"] += int(repo_result["agent_dispatch"].get("failed", False))
            report["repos"].append(repo_result)

        report["finished_at"] = utc_now().isoformat()
        return report

    def _handle_rebases(self, repo: str, settings: dict[str, Any]) -> dict[str, Any]:
        if not settings["rules"].get("auto_rebase_ready_prs", False):
            return {"enabled": False, "updated": 0, "failed": 0, "actions": []}

        prs: list[dict[str, Any]] = self.gh.json(
            [
                "pr",
                "list",
                "--repo",
                repo,
                "--state",
                "open",
                "--limit",
                "200",
                "--json",
                "number,isDraft,mergeStateStatus,labels,url,title,headRepositoryOwner,headRepository,maintainerCanModify",
            ]
        )

        actions: list[dict[str, Any]] = []
        updated = 0
        failed = 0

        base_owner = repo.split("/", 1)[0]

        for pr in prs:
            eligible, reason = evaluate_rebase_eligibility(pr, base_owner, settings["skip_labels"])
            action = {
                "pr": pr["number"],
                "url": pr["url"],
                "title": pr["title"],
                "eligible": eligible,
                "reason": reason,
            }

            if not eligible:
                actions.append(action)
                continue

            if updated >= settings["max_pr_updates_per_run"]:
                action.update({"eligible": False, "reason": "max_updates_reached"})
                actions.append(action)
                continue

            if self.dry_run:
                action["result"] = "would_rebase"
                updated += 1
                actions.append(action)
                continue

            cmd = ["pr", "update-branch", str(pr["number"]), "--rebase", "--repo", repo]
            result = self.gh.run(cmd)
            if result.returncode == 0:
                action["result"] = "rebased"
                updated += 1
            else:
                action["result"] = "failed"
                action["error"] = result.stderr.strip() or result.stdout.strip()
                failed += 1
            actions.append(action)

        return {
            "enabled": True,
            "updated": updated,
            "failed": failed,
            "actions": actions,
        }

    def _handle_dispatch(self, repo: str, settings: dict[str, Any]) -> dict[str, Any]:
        if not settings["rules"].get("dispatch_agent_scan", False):
            return {"enabled": False, "dispatched": False, "failed": False, "reason": "rule_disabled"}

        event_type = settings["agent_dispatch"].get("event_type", "automation.scan")
        open_pr_label = settings["agent_dispatch"].get("open_pr_label", "automation/proactive")

        open_scan_prs: list[dict[str, Any]] = self.gh.json(
            [
                "pr",
                "list",
                "--repo",
                repo,
                "--state",
                "open",
                "--search",
                f"label:{open_pr_label}",
                "--limit",
                "1",
                "--json",
                "number,url,createdAt",
            ]
        )
        if open_scan_prs:
            return {
                "enabled": True,
                "dispatched": False,
                "failed": False,
                "reason": "open_scan_pr_exists",
                "open_pr": open_scan_prs[0],
            }

        latest_scan_prs: list[dict[str, Any]] = self.gh.json(
            [
                "pr",
                "list",
                "--repo",
                repo,
                "--state",
                "all",
                "--search",
                f"label:{open_pr_label} sort:created-desc",
                "--limit",
                "1",
                "--json",
                "number,url,createdAt",
            ]
        )

        if latest_scan_prs:
            latest = latest_scan_prs[0]
            latest_created = parse_time(latest["createdAt"])
            cutoff = utc_now() - dt.timedelta(days=settings["scan_cooldown_days"])
            if latest_created >= cutoff:
                return {
                    "enabled": True,
                    "dispatched": False,
                    "failed": False,
                    "reason": "cooldown_active",
                    "latest_pr": latest,
                }

        payload = {
            "event_type": event_type,
            "client_payload": {
                "source_repo": str(Path.cwd()),
                "source_workflow_run_id": "",
                "dispatched_at": utc_now().isoformat(),
                "intent": "proactive_scan",
            },
        }

        github_repository = os.environ.get("GITHUB_REPOSITORY", str(Path.cwd()))
        github_run_id = os.environ.get("GITHUB_RUN_ID", "")
        payload["client_payload"]["source_repo"] = github_repository
        payload["client_payload"]["source_workflow_run_id"] = github_run_id

        if self.dry_run:
            return {
                "enabled": True,
                "dispatched": True,
                "failed": False,
                "reason": "would_dispatch",
                "event_type": event_type,
            }

        result = self.gh.run(
            ["api", f"repos/{repo}/dispatches", "--method", "POST", "--input", "-"],
            stdin=json.dumps(payload),
        )
        if result.returncode != 0:
            return {
                "enabled": True,
                "dispatched": False,
                "failed": True,
                "reason": "dispatch_failed",
                "error": result.stderr.strip() or result.stdout.strip(),
            }

        return {
            "enabled": True,
            "dispatched": True,
            "failed": False,
            "reason": "dispatched",
            "event_type": event_type,
        }


def markdown_summary(report: dict[str, Any]) -> str:
    lines = [
        "# GitHub Automation Report",
        "",
        f"- Dry run: `{report['dry_run']}`",
        f"- Repositories processed: `{report['totals']['repos_processed']}`",
        f"- PR branches rebased: `{report['totals']['rebase_updated']}`",
        f"- PR rebase failures: `{report['totals']['rebase_failed']}`",
        f"- Agent scans dispatched: `{report['totals']['scan_dispatched']}`",
        f"- Agent dispatch failures: `{report['totals']['scan_failed']}`",
        "",
        "## Per Repository",
    ]
    for item in report["repos"]:
        lines.append(f"- `{item['repo']}`: rebased `{item['auto_rebase']['updated']}`, dispatch `{item['agent_dispatch']['reason']}`")
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run scheduled GitHub automation policies.")
    parser.add_argument("--config", required=True, help="Path to repo config JSON file")
    parser.add_argument("--output", required=True, help="Path to JSON report output")
    parser.add_argument("--summary", required=True, help="Path to markdown summary output")
    parser.add_argument("--dry-run", action="store_true", help="Evaluate actions without mutating GitHub state")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = json.loads(Path(args.config).read_text(encoding="utf-8"))

    controller = Controller(gh=GhClient(), dry_run=args.dry_run)
    report = controller.run(config)

    output_path = Path(args.output)
    output_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    summary_path = Path(args.summary)
    summary_path.write_text(markdown_summary(report), encoding="utf-8")

    has_failures = report["totals"]["rebase_failed"] > 0 or report["totals"]["scan_failed"] > 0
    return 1 if has_failures else 0


if __name__ == "__main__":
    sys.exit(main())
