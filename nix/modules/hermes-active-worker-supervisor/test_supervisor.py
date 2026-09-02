#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location(
    "active_worker_supervisor", HERE / "supervisor.py"
)
assert SPEC and SPEC.loader
SUPERVISOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SUPERVISOR)
REGISTRY = HERE / "worker_registry.py"


class SupervisorTests(unittest.TestCase):
    def test_baseline_is_silent_and_change_wakes(self) -> None:
        baseline = {"registration_errors": [], "tasks": []}
        wake, reason, state = SUPERVISOR.decide_wake(baseline, {}, 100)
        self.assertFalse(wake)
        self.assertEqual(reason, "baseline")

        changed = {"registration_errors": [], "tasks": [{"metadata": {"id": "worker"}}]}
        wake, reason, _ = SUPERVISOR.decide_wake(changed, state, 110)
        self.assertTrue(wake)
        self.assertEqual(reason, "state_changed")

    def test_unhealthy_baseline_wakes(self) -> None:
        snapshot = {
            "registration_errors": [],
            "tasks": [
                {
                    "metadata": {"id": "worker", "status": "active"},
                    "worker": {
                        "status": "ok",
                        "unit": {"active": "inactive"},
                        "processes": [],
                    },
                }
            ],
        }
        wake, reason, _ = SUPERVISOR.decide_wake(snapshot, {}, 100)
        self.assertTrue(wake)
        self.assertEqual(reason, "baseline_requires_attention")

    def test_missing_checkout_wakes_on_baseline(self) -> None:
        snapshot = {
            "registration_errors": [],
            "tasks": [
                {
                    "metadata": {"id": "worker", "status": "active"},
                    "worker": {
                        "status": "ok",
                        "unit": {"active": "active"},
                        "processes": ["pi"],
                        "checkout": {"head": "missing"},
                    },
                }
            ],
        }
        wake, reason, _ = SUPERVISOR.decide_wake(snapshot, {}, 100)
        self.assertTrue(wake)
        self.assertEqual(reason, "baseline_requires_attention")

    def test_stall_wakes_once_for_one_signature(self) -> None:
        snapshot = {
            "registration_errors": [],
            "tasks": [
                {
                    "metadata": {"id": "worker", "status": "active"},
                    "worker": {
                        "unit": {"active": "active"},
                        "processes": ["pi --mode json"],
                    },
                }
            ],
        }
        signature = SUPERVISOR.stable_signature(snapshot["tasks"][0])
        previous = {
            "signature": SUPERVISOR.stable_signature(snapshot),
            "tasks": {
                "worker": {
                    "signature": signature,
                    "last_change_at": 100,
                    "stall_alert_signature": None,
                }
            },
        }
        wake, reason, state = SUPERVISOR.decide_wake(
            snapshot, previous, 100 + SUPERVISOR.STALL_AFTER_SECONDS
        )
        self.assertTrue(wake)
        self.assertEqual(reason, "possible_stall")

        wake, reason, _ = SUPERVISOR.decide_wake(snapshot, state, 10000)
        self.assertFalse(wake)
        self.assertEqual(reason, "unchanged")

    def test_worker_progress_does_not_reset_another_worker_stall(self) -> None:
        idle = {
            "metadata": {"id": "idle", "status": "active"},
            "worker": {"unit": {"active": "active"}, "processes": ["pi"]},
        }
        busy_before = {
            "metadata": {"id": "busy", "status": "active"},
            "worker": {"unit": {"active": "active"}, "processes": ["pi"]},
        }
        before = {"registration_errors": [], "tasks": [idle, busy_before]}
        previous = {
            "signature": SUPERVISOR.stable_signature(before),
            "tasks": {
                task["metadata"]["id"]: {
                    "signature": SUPERVISOR.stable_signature(task),
                    "last_change_at": 100,
                    "stall_alert_signature": None,
                }
                for task in before["tasks"]
            },
        }
        busy_after = {
            **busy_before,
            "worker": {"unit": {"active": "active"}, "processes": ["pi", "nix"]},
        }
        after = {"registration_errors": [], "tasks": [idle, busy_after]}
        wake, reason, state = SUPERVISOR.decide_wake(
            after, previous, 100 + SUPERVISOR.STALL_AFTER_SECONDS
        )
        self.assertTrue(wake)
        self.assertEqual(reason, "possible_stall")
        self.assertEqual(state["stalled_tasks"], ["idle"])
        self.assertEqual(state["tasks"]["idle"]["last_change_at"], 100)
        self.assertEqual(
            state["tasks"]["idle"]["stall_alert_signature"],
            SUPERVISOR.stable_signature(idle),
        )

    def test_corrupt_state_time_falls_back_without_crashing(self) -> None:
        task = {
            "metadata": {"id": "worker", "status": "active"},
            "worker": {"unit": {"active": "active"}, "processes": ["pi"]},
        }
        snapshot = {"registration_errors": [], "tasks": [task]}
        previous = {
            "signature": SUPERVISOR.stable_signature(snapshot),
            "tasks": {
                "worker": {
                    "signature": SUPERVISOR.stable_signature(task),
                    "last_change_at": "invalid",
                }
            },
        }
        wake, reason, state = SUPERVISOR.decide_wake(snapshot, previous, 100)
        self.assertFalse(wake)
        self.assertEqual(reason, "unchanged")
        self.assertEqual(state["tasks"]["worker"]["last_change_at"], 100)

    def test_remote_probe_omits_process_ids(self) -> None:
        parsed = SUPERVISOR.parse_remote_probe(
            {
                "status": "ok",
                "stdout": (
                    "UNIT\tloaded\tactive\trunning\tsuccess\t0\n"
                    "PROCESS\tpi --mode json\n"
                    "REPO\tabc123\tfeature\tworktreehash\n"
                    "RESULT\tpresent\tresulthash\n"
                ),
            }
        )
        self.assertEqual(parsed["processes"], ["pi --mode json"])
        self.assertNotIn("pid", json.dumps(parsed).lower())

    def test_github_checks_drop_transient_times(self) -> None:
        checks = SUPERVISOR.normalize_checks(
            [
                {
                    "name": "test",
                    "status": "COMPLETED",
                    "conclusion": "SUCCESS",
                    "startedAt": "2026-09-02T00:00:00Z",
                    "completedAt": "2026-09-02T00:01:00Z",
                }
            ]
        )
        self.assertEqual(
            checks,
            [{"name": "test", "status": "COMPLETED", "conclusion": "SUCCESS"}],
        )

    def test_linked_worktree_is_probed_as_a_repository(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository = root / "repository"
            worktree = root / "worktree"
            binary = root / "bin"
            binary.mkdir()
            systemctl = binary / "systemctl"
            systemctl.write_text(
                f"#!{shutil.which('bash')}\n"
                'case "$*" in\n'
                "  *show-environment*) exit 0 ;;\n"
                "  *LoadState*) echo loaded ;;\n"
                "  *ActiveState*) echo inactive ;;\n"
                "  *SubState*) echo dead ;;\n"
                "  *Result*) echo success ;;\n"
                "  *ExecMainStatus*) echo 0 ;;\n"
                "  *ControlGroup*) echo ;;\n"
                "esac\n"
            )
            systemctl.chmod(0o755)
            subprocess.run(
                ["git", "init", str(repository)], check=True, capture_output=True
            )
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(repository),
                    "config",
                    "user.email",
                    "test@example.com",
                ],
                check=True,
            )
            subprocess.run(
                ["git", "-C", str(repository), "config", "user.name", "Test"],
                check=True,
            )
            (repository / "tracked.txt").write_text("tracked\n")
            subprocess.run(["git", "-C", str(repository), "add", "."], check=True)
            subprocess.run(
                ["git", "-C", str(repository), "commit", "-m", "initial"],
                check=True,
                capture_output=True,
            )
            subprocess.run(
                ["git", "-C", str(repository), "worktree", "add", str(worktree)],
                check=True,
                capture_output=True,
            )
            environment = os.environ.copy()
            environment["PATH"] = f"{binary}:{environment['PATH']}"
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    SUPERVISOR.REMOTE_PROBE,
                    "--",
                    "worker.service",
                    str(worktree),
                    "",
                ],
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            parsed = SUPERVISOR.parse_remote_probe(
                {"status": "ok", "stdout": result.stdout}
            )
            self.assertNotEqual(parsed["checkout"]["head"], "missing")

    def test_registration_requires_matching_filename(self) -> None:
        with self.assertRaisesRegex(ValueError, "filename must match id"):
            SUPERVISOR.validate_metadata(
                {
                    "id": "worker-a",
                    "status": "active",
                    "host": "nemesis",
                    "unit": "worker.service",
                    "checkout": "/tmp/worker",
                },
                Path("worker-b.json"),
            )


class RegistryCommandTests(unittest.TestCase):
    def run_registry(
        self, directory: Path, *arguments: str
    ) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["HERMES_ACTIVE_WORKER_DIR"] = str(directory)
        return subprocess.run(
            [sys.executable, str(REGISTRY), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )

    def test_register_lifecycle_and_remove(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            register = self.run_registry(
                directory,
                "register",
                "worker-a",
                "--host",
                "nemesis",
                "--unit",
                "worker-a.service",
                "--checkout",
                "/tmp/worker-a",
                "--repository",
                "rrvsh/tools",
                "--pr",
                "123",
                "--result-file",
                "/tmp/worker-a-result.txt",
            )
            self.assertEqual(register.returncode, 0, register.stderr)

            repeat = self.run_registry(
                directory,
                "register",
                "worker-a",
                "--host",
                "nemesis",
                "--unit",
                "worker-a.service",
                "--checkout",
                "/tmp/worker-a",
                "--repository",
                "rrvsh/tools",
                "--pr",
                "123",
                "--result-file",
                "/tmp/worker-a-result.txt",
            )
            self.assertEqual(repeat.returncode, 0, repeat.stderr)

            invalid_pr = self.run_registry(
                directory,
                "register",
                "worker-b",
                "--host",
                "nemesis",
                "--unit",
                "worker-b.service",
                "--checkout",
                "/tmp/worker-b",
                "--repository",
                "rrvsh/tools",
                "--pr",
                "-1",
            )
            self.assertNotEqual(invalid_pr.returncode, 0)

            completed = self.run_registry(directory, "completed", "worker-a")
            self.assertEqual(completed.returncode, 0, completed.stderr)
            worker = json.loads((directory / "worker-a.json").read_text())
            self.assertEqual(worker["status"], "completed")

            removed = self.run_registry(directory, "remove", "worker-a")
            self.assertEqual(removed.returncode, 0, removed.stderr)
            self.assertFalse((directory / "worker-a.json").exists())

    def test_lifecycle_refuses_mismatched_stored_id(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "worker-a.json").write_text(
                json.dumps(
                    {
                        "id": "worker-b",
                        "status": "active",
                        "host": "nemesis",
                        "unit": "worker.service",
                        "checkout": "/tmp/worker",
                    }
                )
            )
            result = self.run_registry(directory, "completed", "worker-a")
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((directory / "worker-b.json").exists())


if __name__ == "__main__":
    unittest.main()
