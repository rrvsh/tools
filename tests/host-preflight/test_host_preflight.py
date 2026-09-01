from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/host-preflight"
FIXTURES = Path(__file__).parent / "fixtures"
BASE = json.loads((FIXTURES / "base.json").read_text())
CASES = json.loads((FIXTURES / "cases.json").read_text())


def merge(base: dict[str, Any], changes: dict[str, Any]) -> dict[str, Any]:
    if changes.get("__replace__"):
        return {key: value for key, value in changes.items() if key != "__replace__"}
    result = copy.deepcopy(base)
    for key, value in changes.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result


class HostPreflightTests(unittest.TestCase):
    def run_case(
        self,
        case: str | None = None,
        *,
        target: str = "nemesis",
        command: str = "preflight",
        configuration: str | None = None,
        output_json: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        facts = BASE if case is None else merge(BASE, CASES[case])
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as fixture:
            json.dump(facts, fixture)
            fixture.flush()
            arguments = [
                sys.executable,
                str(SCRIPT),
                command,
                "--target",
                target,
                "--expected-branch",
                "feat/host-preflight",
                "--expected-sha",
                "0123456",
                "--fixture",
                fixture.name,
            ]
            if configuration:
                arguments.extend(["--configuration", configuration])
            if output_json:
                arguments.append("--json")
            return subprocess.run(arguments, check=False, capture_output=True, text=True)

    def failed_checks(self, case: str, *, target: str = "nemesis") -> set[str]:
        result = self.run_case(case, target=target)
        self.assertEqual(result.returncode, 2)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "refuse")
        return {check["name"] for check in report["checks"] if not check["passed"]}

    def test_clean_checkout_passes(self) -> None:
        result = self.run_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "pass")
        self.assertEqual(
            report["relevant_configuration"]["target"],
            ".#nixosConfigurations.nemesis.config.system.build.toplevel",
        )
        self.assertIn("active", report["activation_verification_reminder"])

    def test_branch_mismatch_refuses(self) -> None:
        self.assertIn("branch_matches", self.failed_checks("branch-mismatch"))

    def test_dirty_and_untracked_nix_source_refuse(self) -> None:
        failures = self.failed_checks("dirty-untracked")
        self.assertIn("checkout_clean", failures)
        self.assertIn("nix_sources_tracked", failures)

    def test_missing_peer_is_offline_and_refuses(self) -> None:
        failures = self.failed_checks("missing-peer", target="alpha")
        self.assertEqual(failures, {"peer_reachable"})

    def test_wrong_host_refuses(self) -> None:
        self.assertIn("host_matches", self.failed_checks("wrong-host"))

    def test_tool_shadowing_refuses(self) -> None:
        self.assertIn("tool_nix_trusted", self.failed_checks("tool-shadowing"))

    def test_absent_configuration_refuses(self) -> None:
        result = self.run_case(configuration="missing")
        self.assertEqual(result.returncode, 2)
        failures = {
            check["name"] for check in json.loads(result.stdout)["checks"] if not check["passed"]
        }
        self.assertIn("configuration_exists", failures)

    def test_json_is_stable_and_sorted(self) -> None:
        first = self.run_case()
        second = self.run_case()
        self.assertEqual(first.stdout, second.stdout)
        parsed = json.loads(first.stdout)
        self.assertEqual(first.stdout, json.dumps(parsed, indent=2, sort_keys=True) + "\n")

    def test_peer_plan_only_prints_quoted_commands(self) -> None:
        result = self.run_case(command="peer-plan", output_json=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("peer-plan: PRINT ONLY", result.stdout)
        self.assertIn("nix develop -c just check-nix", result.stdout)
        self.assertIn("nix develop -c just rb", result.stdout)
        self.assertIn("No command below was executed.", result.stdout)

    def test_remote_peer_plan_prints_same_branch_fast_forward_pull(self) -> None:
        result = self.run_case("clean-peer", target="alpha", command="peer-plan", output_json=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "git pull --ff-only nemesis feat/host-preflight",
            result.stdout,
        )
        self.assertIn("ssh alpha", result.stdout)

    def test_peer_plan_refuses_after_failed_preflight(self) -> None:
        result = self.run_case("branch-mismatch", command="peer-plan", output_json=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("branch_matches", result.stderr)
        self.assertNotIn("just rb", result.stdout)


if __name__ == "__main__":
    unittest.main()
