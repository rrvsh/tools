#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
RECONCILE = HERE / "reconcile.sh"
MANAGED_NAME = "active-worker-heartbeat"
MANAGED_ID = "abc123def456"
OTHER_ID = "111111111111"


class ReconcileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.home = self.root / "hermes"
        (self.home / "cron").mkdir(parents=True)
        self.prompt = self.root / "prompt.txt"
        self.prompt.write_text("Supervise registered workers.\n")
        self.log = self.root / "hermes.log"
        self.hermes = self.root / "fake-hermes"
        self.hermes.write_text(
            f"#!{shutil.which('bash')}\n"
            'printf \'%q \' "$@" >>"$HERMES_TEST_LOG"\n'
            "printf '\\n' >>\"$HERMES_TEST_LOG\"\n"
            'if [ "${1:-}" = cron ] && [ "${2:-}" = create ]; then\n'
            f"  echo 'Created job: {MANAGED_ID}'\n"
            "fi\n"
        )
        self.hermes.chmod(0o755)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_reconcile(self) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment.update(
            {
                "HERMES_BIN": str(self.hermes),
                "HERMES_HOME": str(self.home),
                "HERMES_JOB_PROMPT": str(self.prompt),
                "HERMES_JOB_NAME": MANAGED_NAME,
                "HERMES_JOB_DELIVERY": "telegram:384288005",
                "HERMES_TEST_LOG": str(self.log),
            }
        )
        return subprocess.run(
            ["bash", str(RECONCILE)],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )

    def write_jobs(self, jobs: list[dict[str, str]]) -> None:
        (self.home / "cron" / "jobs.json").write_text(
            json.dumps({"version": 1, "jobs": jobs})
        )

    def commands(self) -> str:
        return self.log.read_text() if self.log.exists() else ""

    def test_creates_records_and_reconciles_owned_job(self) -> None:
        result = self.run_reconcile()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = self.home / "cron" / "nix-active-worker-heartbeat-job-id"
        self.assertEqual(manifest.read_text().strip(), MANAGED_ID)
        commands = self.commands()
        self.assertIn("cron create", commands)
        self.assertIn("--continuity", commands)
        self.assertIn("telegram:384288005", commands)
        self.assertIn(f"cron edit {MANAGED_ID}", commands)
        self.assertIn(f"cron resume {MANAGED_ID}", commands)

    def test_adopts_one_exact_name_without_touching_unrelated_job(self) -> None:
        self.write_jobs(
            [
                {"id": OTHER_ID, "name": "unrelated"},
                {"id": MANAGED_ID, "name": MANAGED_NAME},
            ]
        )
        result = self.run_reconcile()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        self.assertNotIn("cron create", commands)
        self.assertIn(f"cron edit {MANAGED_ID}", commands)
        self.assertNotIn(OTHER_ID, commands)

    def test_refuses_duplicate_names(self) -> None:
        self.write_jobs(
            [
                {"id": MANAGED_ID, "name": MANAGED_NAME},
                {"id": OTHER_ID, "name": MANAGED_NAME},
            ]
        )
        result = self.run_reconcile()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_refuses_duplicate_names_when_manifest_exists(self) -> None:
        self.write_jobs(
            [
                {"id": MANAGED_ID, "name": MANAGED_NAME},
                {"id": OTHER_ID, "name": MANAGED_NAME},
            ]
        )
        (self.home / "cron" / "nix-active-worker-heartbeat-job-id").write_text(
            f"{MANAGED_ID}\n"
        )
        result = self.run_reconcile()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_refuses_manifest_that_points_to_foreign_job(self) -> None:
        self.write_jobs([{"id": MANAGED_ID, "name": "foreign"}])
        (self.home / "cron" / "nix-active-worker-heartbeat-job-id").write_text(
            f"{MANAGED_ID}\n"
        )
        result = self.run_reconcile()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_refuses_invalid_job_store(self) -> None:
        (self.home / "cron" / "jobs.json").write_text('{"jobs":"invalid"}\n')
        result = self.run_reconcile()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), "")


if __name__ == "__main__":
    unittest.main()
