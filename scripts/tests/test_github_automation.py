import unittest

from ..github_automation import CommandResult, Controller, evaluate_rebase_eligibility, markdown_summary


class RebaseEligibilityTests(unittest.TestCase):
    def test_draft_pr_is_not_eligible(self) -> None:
        eligible, reason = evaluate_rebase_eligibility(
            {
                "isDraft": True,
                "mergeStateStatus": "BEHIND",
                "labels": [],
                "headRepositoryOwner": {"login": "rrvsh"},
                "maintainerCanModify": True,
                "headRepository": {"owner": {"login": "rrvsh"}},
            },
            "rrvsh",
            [],
        )
        self.assertFalse(eligible)
        self.assertEqual(reason, "draft")

    def test_non_behind_pr_is_not_eligible(self) -> None:
        eligible, reason = evaluate_rebase_eligibility(
            {
                "isDraft": False,
                "mergeStateStatus": "CLEAN",
                "labels": [],
                "headRepositoryOwner": {"login": "rrvsh"},
                "maintainerCanModify": True,
                "headRepository": {"owner": {"login": "rrvsh"}},
            },
            "rrvsh",
            [],
        )
        self.assertFalse(eligible)
        self.assertEqual(reason, "merge_state_clean")

    def test_skip_label_excludes_pr(self) -> None:
        eligible, reason = evaluate_rebase_eligibility(
            {
                "isDraft": False,
                "mergeStateStatus": "BEHIND",
                "labels": [{"name": "no-auto-rebase"}],
                "headRepositoryOwner": {"login": "rrvsh"},
                "maintainerCanModify": True,
                "headRepository": {"owner": {"login": "rrvsh"}},
            },
            "rrvsh",
            ["no-auto-rebase"],
        )
        self.assertFalse(eligible)
        self.assertEqual(reason, "skip_label")


class SummaryTests(unittest.TestCase):
    def test_markdown_summary_includes_totals(self) -> None:
        report = {
            "dry_run": True,
            "totals": {
                "repos_processed": 1,
                "rebase_updated": 2,
                "rebase_failed": 0,
                "scan_dispatched": 1,
                "scan_failed": 0,
            },
            "repos": [
                {
                    "repo": "rrvsh/tools",
                    "auto_rebase": {"updated": 2},
                    "agent_dispatch": {"reason": "would_dispatch"},
                }
            ],
        }
        summary = markdown_summary(report)
        self.assertIn("PR branches rebased: `2`", summary)
        self.assertIn("`rrvsh/tools`", summary)


class FakeGh:
    def __init__(self) -> None:
        self.calls = []

    def run(self, args, stdin=None):
        self.calls.append(("run", args, stdin))
        return CommandResult(returncode=0, stdout="", stderr="")

    def json(self, args, stdin=None):
        self.calls.append(("json", args, stdin))
        command = " ".join(args)
        if "--state open" in command and "label:automation/proactive" not in command:
            return [
                {
                    "number": 11,
                    "isDraft": False,
                    "mergeStateStatus": "BEHIND",
                    "labels": [],
                    "url": "https://example/pr/11",
                    "title": "Update deps",
                    "headRepositoryOwner": {"login": "rrvsh"},
                    "headRepository": {"owner": {"login": "rrvsh"}},
                    "maintainerCanModify": True,
                },
                {
                    "number": 12,
                    "isDraft": False,
                    "mergeStateStatus": "CLEAN",
                    "labels": [],
                    "url": "https://example/pr/12",
                    "title": "Already up to date",
                    "headRepositoryOwner": {"login": "rrvsh"},
                    "headRepository": {"owner": {"login": "rrvsh"}},
                    "maintainerCanModify": True,
                },
            ]
        if "--state open" in command and "label:automation/proactive" in command:
            return []
        if "--state all" in command and "label:automation/proactive" in command:
            return []
        return []


class ControllerTests(unittest.TestCase):
    def test_controller_dry_run_counts_rebase_and_dispatch(self) -> None:
        fake = FakeGh()
        controller = Controller(gh=fake, dry_run=True)
        report = controller.run(
            {
                "defaults": {
                    "skip_labels": [],
                    "max_pr_updates_per_run": 5,
                    "scan_cooldown_days": 7,
                    "agent_dispatch": {
                        "event_type": "automation.scan",
                        "open_pr_label": "automation/proactive",
                    },
                },
                "repos": [
                    {
                        "name": "rrvsh/tools",
                        "enabled": True,
                        "rules": {
                            "auto_rebase_ready_prs": True,
                            "dispatch_agent_scan": True,
                        },
                    }
                ],
            }
        )
        self.assertEqual(report["totals"]["rebase_updated"], 1)
        self.assertEqual(report["totals"]["scan_dispatched"], 1)


if __name__ == "__main__":
    unittest.main()
