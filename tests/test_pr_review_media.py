from __future__ import annotations

import importlib.util
import io
import json
import os
import stat
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stderr, redirect_stdout
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest import mock

from PIL import Image

SCRIPT = Path(__file__).parents[1] / "scripts" / "pr-review-media.py"
SPEC = importlib.util.spec_from_file_location("pr_review_media", SCRIPT)
assert SPEC and SPEC.loader
media = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = media
SPEC.loader.exec_module(media)


FAKE_GH = r"""#!/usr/bin/env python3
import hashlib
import json
import os
import re
import sys
from pathlib import Path

args = sys.argv[1:]
state_path = Path(os.environ["FAKE_GH_STATE"])
state = json.loads(state_path.read_text())
if args == ["pr", "edit", "--help"]:
    if os.environ.get("FAKE_GH_ATTACH") == "1":
        print("FLAGS\n      --attach file   Attach a file")
    else:
        print("FLAGS\n      --body text")
    raise SystemExit(0)
if args[:2] == ["pr", "view"]:
    print(json.dumps({"body": state["body"]}))
    raise SystemExit(0)
if args[:2] == ["repo", "view"]:
    print(json.dumps({"visibility": state.get("visibility", "PUBLIC")}))
    raise SystemExit(0)
if args[:2] == ["pr", "edit"]:
    body = sys.stdin.read()
    attachments = [args[index + 1] for index, value in enumerate(args) if value == "--attach"]
    count = len(attachments)
    if os.environ.get("FAKE_GH_PARTIAL_ONCE") == "1" and state.get("edits", 0) == 0:
        count = min(count, 1)
    for attachment in attachments[:count]:
        path, alt = attachment.rsplit("#", 1)
        asset = hashlib.sha256(path.encode()).hexdigest()[:12]
        url = "https://github.com/user-attachments/assets/11111111-1111-1111-1111-" + asset
        body = body.replace(f"![{alt}]({path})", f"![{alt}]({url})")
    state["body"] = body
    state["edits"] = state.get("edits", 0) + 1
    state_path.write_text(json.dumps(state))
    if count != len(attachments):
        print("upload failed; Authorization: Bearer github_pat_secretvalue", file=sys.stderr)
        raise SystemExit(1)
    print("https://github.test/pull/7")
    raise SystemExit(0)
print("unexpected fake gh call: " + repr(args), file=sys.stderr)
raise SystemExit(3)
"""


class Workspace:
    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "artifacts"
        self.root.mkdir(mode=0o700)
        os.chmod(self.root, 0o700)

    def close(self) -> None:
        self.temporary.cleanup()

    def image(self, name: str, colors=((10, 20, 30), (220, 210, 200))) -> None:
        image = Image.new("RGB", (64, 64), colors[0])
        for x in range(32, 64):
            for y in range(64):
                image.putpixel((x, y), colors[1])
        image.save(self.root / name)
        os.chmod(self.root / name, 0o600)

    def manifest(self, images: list[dict[str, str]]) -> None:
        path = self.root / "manifest.json"
        path.write_text(json.dumps({"images": images}))
        os.chmod(path, 0o600)


class ValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.workspace = Workspace()

    def tearDown(self) -> None:
        self.workspace.close()

    def test_valid_manifest_checks_bytes_dimensions_and_content(self) -> None:
        self.workspace.image("wide.png")
        self.workspace.manifest([{"path": "wide.png", "alt": "Wide view"}])
        rows = media.load_manifest(self.workspace.root, "manifest.json", None)
        self.assertEqual(
            (rows[0].width, rows[0].height, rows[0].media_type), (64, 64, "image/png")
        )

    def test_rejects_malformed_and_duplicate_rows(self) -> None:
        self.workspace.image("wide.png")
        self.workspace.manifest(
            [
                {"path": "wide.png", "alt": "Wide view"},
                {"path": "wide.png", "alt": "Other view"},
            ]
        )
        with self.assertRaisesRegex(media.MediaError, "duplicate"):
            media.load_manifest(self.workspace.root, "manifest.json", None)
        (self.workspace.root / "manifest.json").write_text("not json")
        with self.assertRaisesRegex(media.MediaError, "malformed"):
            media.load_manifest(self.workspace.root, "manifest.json", None)

    def test_rejects_unsupported_and_invalid_image_bytes(self) -> None:
        bad = self.workspace.root / "bad.svg"
        bad.write_text("<svg/>")
        os.chmod(bad, 0o600)
        self.workspace.manifest([{"path": "bad.svg", "alt": "Bad"}])
        with self.assertRaisesRegex(media.MediaError, "unsupported"):
            media.load_manifest(self.workspace.root, "manifest.json", None)
        bad.rename(self.workspace.root / "bad.png")
        self.workspace.manifest([{"path": "bad.png", "alt": "Bad"}])
        with self.assertRaisesRegex(media.MediaError, "invalid image bytes"):
            media.load_manifest(self.workspace.root, "manifest.json", None)

    def test_rejects_blank_image_even_with_valid_dimensions(self) -> None:
        Image.new("RGB", (64, 64), "white").save(self.workspace.root / "blank.png")
        os.chmod(self.workspace.root / "blank.png", 0o600)
        self.workspace.manifest([{"path": "blank.png", "alt": "Blank"}])
        with self.assertRaisesRegex(media.MediaError, "blank or uniform"):
            media.load_manifest(self.workspace.root, "manifest.json", None)

    def test_rejects_image_over_attachment_limit(self) -> None:
        self.workspace.image("large.png")
        with (self.workspace.root / "large.png").open("ab") as image:
            image.truncate(10 * 1024 * 1024 + 1)
        self.workspace.manifest([{"path": "large.png", "alt": "Large"}])
        with self.assertRaisesRegex(media.MediaError, "10 MB"):
            media.load_manifest(self.workspace.root, "manifest.json", None)

    def test_rejects_symlink_escape_path_escape_and_broad_modes(self) -> None:
        outside = Path(self.workspace.temporary.name) / "outside.png"
        Image.new("RGB", (64, 64), "black").save(outside)
        os.chmod(outside, 0o600)
        (self.workspace.root / "link.png").symlink_to(outside)
        self.workspace.manifest([{"path": "link.png", "alt": "Escape"}])
        with self.assertRaisesRegex(media.MediaError, "symlink"):
            media.load_manifest(self.workspace.root, "manifest.json", None)
        self.workspace.manifest([{"path": "../outside.png", "alt": "Escape"}])
        with self.assertRaisesRegex(media.MediaError, "unsafe manifest path"):
            media.load_manifest(self.workspace.root, "manifest.json", None)
        os.chmod(self.workspace.root, 0o755)
        with self.assertRaisesRegex(media.MediaError, "must have mode 0700"):
            media.validate_artifact_dir(str(self.workspace.root))

    def test_rejects_symlink_in_artifact_directory_path(self) -> None:
        link = Path(self.workspace.temporary.name) / "artifact-link"
        link.symlink_to(self.workspace.root, target_is_directory=True)
        with self.assertRaisesRegex(media.MediaError, "must not contain a symlink"):
            media.validate_artifact_dir(str(link))

    def test_rejects_artifact_directory_inside_git(self) -> None:
        os.mkdir(self.workspace.root / ".git")
        with (
            mock.patch("subprocess.run", return_value=mock.Mock(returncode=0)),
            self.assertRaisesRegex(media.MediaError, "inside a Git"),
        ):
            media.ensure_not_in_git(self.workspace.root)

    def test_visual_inspector_is_fail_closed(self) -> None:
        self.workspace.image("wide.png")
        self.workspace.manifest([{"path": "wide.png", "alt": "Wide view"}])
        inspector = self.workspace.root / "inspect"
        inspector.write_text("#!/bin/sh\nprintf '{\"ok\":false}'\n")
        os.chmod(inspector, 0o700)
        with self.assertRaisesRegex(media.MediaError, "did not approve"):
            media.load_manifest(self.workspace.root, "manifest.json", str(inspector))


class BodyAndSecurityTests(unittest.TestCase):
    def test_marker_update_byte_preserves_everything_else(self) -> None:
        body = (
            "Title  \r\n"
            + media.DEFAULT_START
            + "\nold\n"
            + media.DEFAULT_END
            + "\r\nEnd\n"
        )
        changed = media.replace_region(
            body, media.DEFAULT_START, media.DEFAULT_END, "new"
        )
        prefix, _, suffix = media.split_region(
            body, media.DEFAULT_START, media.DEFAULT_END
        )
        new_prefix, region, new_suffix = media.split_region(
            changed, media.DEFAULT_START, media.DEFAULT_END
        )
        self.assertEqual((new_prefix, new_suffix), (prefix, suffix))
        self.assertEqual(region, "\nnew\n")

    def test_marker_parser_rejects_duplicates_and_order(self) -> None:
        with self.assertRaises(media.MediaError):
            media.split_region("no markers", "<!-- a -->", "<!-- b -->")
        with self.assertRaises(media.MediaError):
            media.split_region("<!-- b --><!-- a -->", "<!-- a -->", "<!-- b -->")
        with self.assertRaises(media.MediaError):
            media.split_region(
                "<!-- a --><!-- a --><!-- b -->", "<!-- a -->", "<!-- b -->"
            )

    def test_url_allowlist(self) -> None:
        good = "https://github.com/user-attachments/assets/11111111-1111-1111-1111-111111111111"
        self.assertEqual(media.validate_url(good), good)
        for unsafe in [
            "http://github.com/user-attachments/assets/11111111-1111-1111-1111-111111111111",
            "https://evil.test/user-attachments/assets/11111111-1111-1111-1111-111111111111",
            "https://github.com/user-attachments/assets/../../token",
        ]:
            with self.assertRaises(media.MediaError):
                media.validate_url(unsafe)

    def test_redacts_tokens_and_headers(self) -> None:
        value = media.redact(
            "Authorization: Bearer github_pat_secretvalue ghp_1234567890"
        )
        self.assertNotIn("secretvalue", value)
        self.assertNotIn("1234567890", value)
        self.assertEqual(value.count("[REDACTED]"), 2)

    def test_anonymous_privacy_check_uses_bounded_http(self) -> None:
        class Handler(BaseHTTPRequestHandler):
            def do_HEAD(self) -> None:
                self.send_response(404 if self.path == "/private" else 200)
                self.end_headers()

            def log_message(self, format: str, *args: object) -> None:
                return

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            root = f"http://127.0.0.1:{server.server_port}"
            self.assertEqual(
                media.verify_anonymous(root + "/public", "PUBLIC"), "HTTP 200"
            )
            self.assertEqual(
                media.verify_anonymous(root + "/private", "PRIVATE"), "HTTP 404"
            )
            with self.assertRaisesRegex(media.MediaError, "anonymously readable"):
                media.verify_anonymous(root + "/public", "PRIVATE")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


class CommandTests(unittest.TestCase):
    def setUp(self) -> None:
        self.workspace = Workspace()
        self.workspace.image("wide.png")
        self.workspace.image("narrow.png", ((30, 40, 50), (200, 100, 20)))
        self.workspace.manifest(
            [
                {"path": "wide.png", "alt": "Wide view"},
                {"path": "narrow.png", "alt": "Narrow view"},
            ]
        )
        self.fake = Path(self.workspace.temporary.name) / "gh"
        self.fake.write_text(FAKE_GH)
        os.chmod(self.fake, 0o700)
        self.gh_state = Path(self.workspace.temporary.name) / "gh-state.json"
        body = (
            "Before  \n"
            + media.DEFAULT_START
            + "\nold\n"
            + media.DEFAULT_END
            + "\nAfter\n"
        )
        self.gh_state.write_text(
            json.dumps({"body": body, "edits": 0, "visibility": "PUBLIC"})
        )
        self.original_body = body
        self.arguments = [
            "pr-review-media",
            "--repo",
            "owner/repo",
            "--pr",
            "7",
            "--artifact-dir",
            str(self.workspace.root),
            "--manifest",
            "manifest.json",
        ]
        self.environment = {
            "PR_REVIEW_MEDIA_GH": str(self.fake),
            "FAKE_GH_STATE": str(self.gh_state),
        }

    def tearDown(self) -> None:
        self.workspace.close()

    def invoke(
        self, extra: list[str], environment: dict[str, str]
    ) -> tuple[int, str, str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with (
            mock.patch.object(sys, "argv", self.arguments + extra),
            mock.patch.dict(os.environ, environment, clear=False),
            redirect_stdout(stdout),
            redirect_stderr(stderr),
        ):
            code = media.main()
        return code, stdout.getvalue(), stderr.getvalue()

    def test_dry_run_is_default_and_makes_no_body_change(self) -> None:
        code, output, error = self.invoke([], self.environment)
        self.assertEqual((code, error), (0, ""))
        self.assertEqual(json.loads(output)["status"], "dry-run")
        self.assertEqual(
            json.loads(self.gh_state.read_text())["body"], self.original_body
        )
        self.assertFalse((self.workspace.root / media.STATE_NAME).exists())

    def test_approved_write_stops_when_official_feature_is_unsupported(self) -> None:
        code, _, error = self.invoke(["--approve-writes"], self.environment)
        self.assertEqual(code, 2)
        self.assertIn("unsupported", error)
        self.assertEqual(json.loads(self.gh_state.read_text())["edits"], 0)

    def test_partial_upload_record_supports_safe_resume(self) -> None:
        environment = self.environment | {
            "FAKE_GH_ATTACH": "1",
            "FAKE_GH_PARTIAL_ONCE": "1",
        }
        code, _, error = self.invoke(["--approve-writes"], environment)
        self.assertEqual(code, 2)
        self.assertIn("[REDACTED]", error)
        self.assertNotIn("secretvalue", error)
        record_path = self.workspace.root / media.STATE_NAME
        self.assertEqual(stat.S_IMODE(record_path.stat().st_mode), 0o600)
        first = json.loads(record_path.read_text())
        self.assertEqual(first["images"]["wide.png"]["status"], "uploaded")
        self.assertEqual(first["images"]["narrow.png"]["status"], "pending")

        with mock.patch.object(media, "verify_anonymous", return_value="HTTP 200"):
            code, output, error = self.invoke(["--approve-writes"], environment)
        self.assertEqual((code, error), (0, ""))
        self.assertEqual(json.loads(output)["status"], "updated")
        final_gh = json.loads(self.gh_state.read_text())
        self.assertEqual(final_gh["edits"], 2)
        final_body = final_gh["body"]
        original_prefix, _, original_suffix = media.split_region(
            self.original_body, media.DEFAULT_START, media.DEFAULT_END
        )
        final_prefix, final_region, final_suffix = media.split_region(
            final_body, media.DEFAULT_START, media.DEFAULT_END
        )
        self.assertEqual(
            (final_prefix, final_suffix), (original_prefix, original_suffix)
        )
        self.assertEqual(
            final_region.count("https://github.com/user-attachments/assets/"), 2
        )
        self.assertEqual(final_body.count(media.DEFAULT_START), 1)
        self.assertEqual(final_body.count(media.DEFAULT_END), 1)


if __name__ == "__main__":
    unittest.main()
