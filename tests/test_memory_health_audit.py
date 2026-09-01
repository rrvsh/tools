import importlib.util
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "scripts/memory_health_audit.py"
SPEC = importlib.util.spec_from_file_location("memory_health_audit", SCRIPT)
AUDIT = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(AUDIT)


class MemoryHealthAuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.agents = self.root / "Agents"
        self.memory = self.agents / "memory"
        self.output = self.agents / "research/memory-audit"
        self.memory.mkdir(parents=True)

    def tearDown(self):
        self.temporary.cleanup()

    def run_audit(self, *extra):
        argv = [
            "--memory-root",
            str(self.memory),
            "--index",
            str(self.agents / "MEMORY.md"),
            "--output-dir",
            str(self.output),
            "--today",
            "2026-09-01",
            "--generated-at",
            "2026-09-01T12:00:00+00:00",
            *extra,
        ]
        result_code = AUDIT.main(argv)
        report = self.output / "2026-09-01T120000Z.md"
        summary = self.output / "2026-09-01T120000Z.json"
        return (
            result_code,
            report,
            summary,
            json.loads(summary.read_text(encoding="utf-8")),
        )

    def test_fixture_findings_redaction_permissions_and_unchanged_hash(self):
        (self.memory / "logs").mkdir()
        (self.memory / "projects").mkdir()
        (self.agents / "MEMORY.md").write_text(
            "- `memory/todo.md`\n- `memory/todo.md`\n- `memory/missing.md`\n",
            encoding="utf-8",
        )
        secret = "very-private-secret-value"
        (self.memory / "todo.md").write_text(
            "2026-01-01 check tools PR #42\n"
            "[broken](projects/absent.md)\n"
            f"api_key = {secret}\n",
            encoding="utf-8",
        )
        duplicate_text = "same file\n"
        (self.memory / "projects/first.md").write_text(duplicate_text, encoding="utf-8")
        (self.memory / "projects/second.md").write_text(
            duplicate_text, encoding="utf-8"
        )
        (self.memory / "logs/note.md").write_text("undated\n", encoding="utf-8")
        (self.memory / "2026-08-01-misplaced.md").write_text(
            "dated\n", encoding="utf-8"
        )
        (self.memory / "note.sync-conflict-20260901.bin").write_text(
            "conflict\n", encoding="utf-8"
        )
        state_file = self.root / "github.json"
        state_file.write_text(
            json.dumps({"rrvsh/tools#42": "closed"}), encoding="utf-8"
        )

        before = AUDIT.tree_hash(self.memory)
        code, report, summary, payload = self.run_audit(
            "--github-state-file", str(state_file)
        )
        after = AUDIT.tree_hash(self.memory)

        self.assertEqual(code, 0)
        self.assertEqual(before, after)
        self.assertTrue(payload["source_tree"]["unchanged"])
        self.assertEqual(payload["counts"]["broken_references"], 2)
        self.assertEqual(payload["counts"]["missing_indexed_files"], 1)
        self.assertEqual(payload["counts"]["duplicate_index_entries"], 1)
        self.assertEqual(payload["counts"]["conflict_copies"], 1)
        self.assertEqual(payload["counts"]["stale_todos"], 1)
        self.assertEqual(payload["counts"]["secret_patterns"], 1)
        self.assertEqual(payload["counts"]["duplicate_candidates"], 1)
        self.assertEqual(payload["counts"]["misplaced_candidates"], 2)
        pr = payload["findings"]["github_pr_references"][0]
        self.assertEqual(pr["state"], "closed")
        self.assertTrue(pr["stale"])
        self.assertEqual(payload["github"]["mode"], "local-state")
        self.assertNotIn(secret, report.read_text(encoding="utf-8"))
        self.assertNotIn(secret, summary.read_text(encoding="utf-8"))
        self.assertIn("[REDACTED]", report.read_text(encoding="utf-8"))
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(report.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(summary.stat().st_mode), 0o600)

    def test_empty_tree_reports_offline_without_failure(self):
        code, _, _, payload = self.run_audit("--offline")

        self.assertEqual(code, 0)
        self.assertEqual(payload["github"]["mode"], "offline")
        self.assertEqual(payload["github"]["errors"], [])
        self.assertTrue(payload["source_tree"]["unchanged"])
        self.assertTrue(all(count == 0 for count in payload["counts"].values()))

    def test_output_inside_memory_tree_is_rejected(self):
        with self.assertRaises(SystemExit):
            AUDIT.parse_args(
                [
                    "--memory-root",
                    str(self.memory),
                    "--output-dir",
                    str(self.memory / "reports"),
                ]
            )

    def test_full_github_reference_uses_local_state(self):
        (self.agents / "MEMORY.md").write_text("", encoding="utf-8")
        (self.memory / "todo.md").write_text(
            "See https://github.com/example/project/pull/12\n", encoding="utf-8"
        )
        state_file = self.root / "github.json"
        state_file.write_text(
            json.dumps({"example/project#12": "open"}), encoding="utf-8"
        )

        _, _, _, payload = self.run_audit("--github-state-file", str(state_file))

        reference = payload["findings"]["github_pr_references"][0]
        self.assertEqual(reference["reference"], "example/project#12")
        self.assertEqual(reference["state"], "open")
        self.assertFalse(reference["stale"])

    def test_tree_hash_includes_modes_and_symlink_targets(self):
        source = self.memory / "source.md"
        source.write_text("value\n", encoding="utf-8")
        link = self.memory / "link.md"
        link.symlink_to("source.md")
        original = AUDIT.tree_hash(self.memory)

        os.chmod(source, 0o600)
        mode_changed = AUDIT.tree_hash(self.memory)
        link.unlink()
        link.symlink_to("other.md")
        target_changed = AUDIT.tree_hash(self.memory)

        self.assertNotEqual(original, mode_changed)
        self.assertNotEqual(mode_changed, target_changed)


if __name__ == "__main__":
    unittest.main()
