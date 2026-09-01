from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[2] / "scripts" / "pr-stack-reconcile.py"


def command(
    *arguments: str, cwd: Path | None = None, check: bool = True
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        arguments,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode:
        raise AssertionError(
            f"command failed: {arguments}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    return result


class Fixture:
    def __init__(self, *, conflict: bool = False, unexpected: bool = False) -> None:
        self.root = Path(tempfile.mkdtemp(prefix="pr-stack-fixture-", dir="/tmp"))
        self.origin = self.root / "origin.git"
        self.stable = self.root / "stable"
        command("git", "init", "--bare", str(self.origin))
        command("git", "clone", str(self.origin), str(self.stable))
        command("git", "config", "user.name", "Fixture", cwd=self.stable)
        command("git", "config", "user.email", "fixture@example.test", cwd=self.stable)
        command("git", "switch", "-c", "prime", cwd=self.stable)
        self.write("src/value.txt", "base\n")
        self.write("lock.txt", "locked\n")
        self.commit("base")
        self.old_base = self.sha()
        command("git", "push", "-u", "origin", "prime", cwd=self.stable)

        command("git", "switch", "-c", "feature/parent", cwd=self.stable)
        self.write("src/value.txt", "parent\n")
        if unexpected:
            self.write("outside.txt", "unexpected\n")
        self.commit("parent")
        self.parent = self.sha()
        command("git", "push", "-u", "origin", "feature/parent", cwd=self.stable)

        command("git", "switch", "-c", "feature/child", cwd=self.stable)
        self.write("src/child.txt", "child\n")
        self.commit("child")
        self.child = self.sha()
        command("git", "push", "-u", "origin", "feature/child", cwd=self.stable)

        command("git", "switch", "prime", cwd=self.stable)
        self.write("src/base-new.txt", "new base\n")
        if conflict:
            self.write("src/value.txt", "conflicting base\n")
        self.commit("advance base")
        self.base = self.sha()
        command("git", "push", "origin", "prime", cwd=self.stable)

        self.gh_data = self.root / "gh.json"
        self.fake_gh = self.root / "gh"
        self.fake_gh.write_text(
            '#!/bin/sh\nset -eu\nexec "$PYTHON" -c \'import json,os; print(json.dumps(json.load(open(os.environ["FAKE_GH_DATA"]))))\'\n'
        )
        self.fake_gh.chmod(0o755)
        self.write_gh(self.parent, self.child)
        temporary = Path(tempfile.mkdtemp(prefix="pr-stack-owned-", dir="/tmp"))
        temporary.rmdir()
        self.tmp_root = temporary

    def write(self, relative: str, content: str) -> None:
        path = self.stable / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def commit(self, message: str) -> None:
        command("git", "add", ".", cwd=self.stable)
        command("git", "commit", "-m", message, cwd=self.stable)

    def sha(self) -> str:
        return command("git", "rev-parse", "HEAD", cwd=self.stable).stdout.strip()

    def write_gh(
        self,
        parent_sha: str,
        child_sha: str,
        *,
        parent_mergeable: str = "MERGEABLE",
        child_mergeable: str = "MERGEABLE",
    ) -> None:
        self.gh_data.write_text(
            json.dumps(
                [
                    {
                        "number": 1,
                        "title": "parent",
                        "url": "https://github.com/example/repo/pull/1",
                        "headRefName": "feature/parent",
                        "headRefOid": parent_sha,
                        "baseRefName": "prime",
                        "isDraft": False,
                        "mergeable": parent_mergeable,
                        "mergeStateStatus": "CLEAN",
                        "state": "OPEN",
                    },
                    {
                        "number": 2,
                        "title": "child",
                        "url": "https://github.com/example/repo/pull/2",
                        "headRefName": "feature/child",
                        "headRefOid": child_sha,
                        "baseRefName": "feature/parent",
                        "isDraft": False,
                        "mergeable": child_mergeable,
                        "mergeStateStatus": "CLEAN",
                        "state": "OPEN",
                    },
                ]
            )
        )

    def args(self, phase: str, *, allowed: str = "src") -> list[str]:
        return [
            phase,
            "--repo",
            str(self.stable),
            "--github-repo",
            "example/repo",
            "--remote",
            "origin",
            "--base-branch",
            "prime",
            "--expected-base-sha",
            self.base,
            "--branch",
            f"feature/parent:{self.parent}:{self.old_base}",
            "--branch",
            f"feature/child:{self.child}:{self.parent}",
            "--allowed-path",
            allowed,
            "--allowed-path",
            "lock.txt",
            "--validation-command",
            "git diff --check",
            "--lockfile-command",
            "test -f lock.txt && git diff --exit-code HEAD -- lock.txt",
            "--tmp-root",
            str(self.tmp_root),
        ]

    def run(
        self, phase: str, *extra: str, allowed: str = "src", check: bool = True
    ) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment.update(
            {
                "PR_STACK_RECONCILE_GH": str(self.fake_gh),
                "FAKE_GH_DATA": str(self.gh_data),
                "PYTHON": sys.executable,
            }
        )
        result = subprocess.run(
            [sys.executable, str(SCRIPT), *self.args(phase, allowed=allowed), *extra],
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if check and result.returncode:
            raise AssertionError(
                f"phase failed: {phase}\nstdout={result.stdout}\nstderr={result.stderr}"
            )
        return result

    def close(self) -> None:
        if self.tmp_root.exists():
            self.run("cleanup", check=False)
        shutil.rmtree(self.root, ignore_errors=True)


class ReconcileTests(unittest.TestCase):
    def test_inspect_is_idempotent_and_reports_child_stack(self) -> None:
        fixture = Fixture()
        self.addCleanup(fixture.close)
        first = fixture.run("inspect")
        second = fixture.run("inspect")
        self.assertEqual(first.stdout, second.stdout)
        report = json.loads(first.stdout)
        self.assertEqual(
            [item["name"] for item in report["branches"]],
            ["feature/parent", "feature/child"],
        )
        self.assertEqual(report["branches"][1]["old_parent_sha"], fixture.parent)

    def test_parent_and_child_rewrite_verify_and_exact_lease_push(self) -> None:
        fixture = Fixture()
        self.addCleanup(fixture.close)
        fixture.run("prepare")
        parent = json.loads(
            fixture.run(
                "rebase",
                "--target",
                "feature/parent",
                "--expected-new-parent-sha",
                fixture.base,
                "--apply-rebase",
            ).stdout
        )
        fixture.run(
            "verify",
            "--target",
            "feature/parent",
            "--expected-new-parent-sha",
            fixture.base,
        )
        fixture.run("push", "--target", "feature/parent", "--apply-push")
        fixture.write_gh(parent["new_sha"], fixture.child)

        child = json.loads(
            fixture.run(
                "rebase",
                "--target",
                "feature/child",
                "--expected-new-parent-sha",
                parent["new_sha"],
                "--apply-rebase",
            ).stdout
        )
        fixture.run(
            "verify",
            "--target",
            "feature/child",
            "--expected-new-parent-sha",
            parent["new_sha"],
        )
        fixture.run("push", "--target", "feature/child", "--apply-push")
        fixture.write_gh(parent["new_sha"], child["new_sha"])
        verified = fixture.run(
            "verify",
            "--target",
            "feature/child",
            "--expected-new-parent-sha",
            parent["new_sha"],
        )
        self.assertEqual(json.loads(verified.stdout)["mergeability_status"], "current")

    def test_stale_lease_is_refused(self) -> None:
        fixture = Fixture()
        self.addCleanup(fixture.close)
        fixture.run("prepare")
        fixture.run(
            "rebase",
            "--target",
            "feature/parent",
            "--expected-new-parent-sha",
            fixture.base,
            "--apply-rebase",
        )
        fixture.run(
            "verify",
            "--target",
            "feature/parent",
            "--expected-new-parent-sha",
            fixture.base,
        )
        command("git", "switch", "feature/parent", cwd=fixture.stable)
        fixture.write("src/lease.txt", "remote changed\n")
        fixture.commit("remote lease change")
        command("git", "push", "origin", "feature/parent", cwd=fixture.stable)
        command("git", "switch", "prime", cwd=fixture.stable)
        result = fixture.run(
            "push", "--target", "feature/parent", "--apply-push", check=False
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("stale lease", result.stdout)

    def test_push_requires_successful_verify_phase(self) -> None:
        fixture = Fixture()
        self.addCleanup(fixture.close)
        fixture.run("prepare")
        fixture.run(
            "rebase",
            "--target",
            "feature/parent",
            "--expected-new-parent-sha",
            fixture.base,
            "--apply-rebase",
        )
        result = fixture.run(
            "push",
            "--target",
            "feature/parent",
            "--apply-push",
            check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("has not passed the verify phase", result.stdout)

    def test_conflict_stops_without_invention(self) -> None:
        fixture = Fixture(conflict=True)
        self.addCleanup(fixture.close)
        fixture.run("prepare")
        result = fixture.run(
            "rebase",
            "--target",
            "feature/parent",
            "--expected-new-parent-sha",
            fixture.base,
            "--apply-rebase",
            check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("rebase stopped", result.stdout)

    def test_unexpected_path_is_refused(self) -> None:
        fixture = Fixture(unexpected=True)
        self.addCleanup(fixture.close)
        result = fixture.run("inspect", check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("unexpected changed paths", result.stdout)

    def test_interrupted_cleanup_and_repeat_cleanup_are_safe(self) -> None:
        fixture = Fixture()
        self.addCleanup(fixture.close)
        fixture.run("prepare")
        worktree = next((fixture.tmp_root / "worktrees").iterdir())
        shutil.rmtree(worktree)
        first = fixture.run("cleanup")
        second = fixture.run("cleanup")
        self.assertTrue(json.loads(first.stdout)["tmp_root_removed"])
        self.assertEqual(json.loads(second.stdout)["removed_worktrees"], [])

    def test_path_escape_inputs_are_refused(self) -> None:
        fixture = Fixture()
        self.addCleanup(fixture.close)
        result = fixture.run("inspect", allowed="../outside", check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("repository-relative", result.stderr)

        nested = fixture.root / "nested" / "owned"
        arguments = fixture.args("inspect")
        arguments[arguments.index(str(fixture.tmp_root))] = str(nested)
        environment = os.environ.copy()
        environment.update(
            {
                "PR_STACK_RECONCILE_GH": str(fixture.fake_gh),
                "FAKE_GH_DATA": str(fixture.gh_data),
                "PYTHON": sys.executable,
            }
        )
        result = subprocess.run(
            [sys.executable, str(SCRIPT), *arguments],
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("direct child of /tmp", result.stdout)


if __name__ == "__main__":
    unittest.main()
