#!/usr/bin/env python3
"""Validate and attach review images to one managed pull-request body region."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageStat, UnidentifiedImageError

DEFAULT_START = "<!-- pr-review-media:start -->"
DEFAULT_END = "<!-- pr-review-media:end -->"
STATE_NAME = ".pr-review-media-upload.json"
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
ASSET_URL_RE = re.compile(
    r"^https://github\.com/user-attachments/assets/"
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)
SUPPORTED_FORMATS = {
    "PNG": "image/png",
    "JPEG": "image/jpeg",
    "GIF": "image/gif",
    "WEBP": "image/webp",
}
EXTENSIONS = {
    ".png": "PNG",
    ".jpg": "JPEG",
    ".jpeg": "JPEG",
    ".gif": "GIF",
    ".webp": "WEBP",
}


class MediaError(Exception):
    """A safe, user-facing failure."""


@dataclass(frozen=True)
class ImageRow:
    path: Path
    relative_path: str
    alt: str
    sha256: str
    width: int
    height: int
    media_type: str


def redact(text: str) -> str:
    patterns = [
        r"(?i)(authorization\s*:\s*(?:bearer|token)\s+)[^\s\"']+",
        r"\b(?:ghp|github_pat|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{8,}\b",
    ]
    for pattern in patterns:
        text = re.sub(
            pattern,
            lambda match: (
                match.group(1) + "[REDACTED]" if match.lastindex else "[REDACTED]"
            ),
            text,
        )
    return text


def fail(message: str) -> None:
    raise MediaError(message)


def check_mode(path: Path, expected: int) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode != expected:
        fail(f"{path} must have mode {expected:04o}, found {mode:04o}")


def ensure_not_in_git(path: Path) -> None:
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--is-inside-work-tree"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode == 0:
        fail(f"artifact directory is inside a Git work tree: {path}")


def validate_artifact_dir(raw: str) -> Path:
    path = Path(raw).expanduser()
    if not path.is_absolute():
        fail("artifact directory must be an absolute path")
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current = current / part
        if current.is_symlink():
            fail("artifact directory path must not contain a symlink")
    try:
        resolved = path.resolve(strict=True)
    except OSError as error:
        fail(f"cannot resolve artifact directory: {error}")
    if not resolved.is_dir():
        fail("artifact directory is not a directory")
    check_mode(resolved, 0o700)
    ensure_not_in_git(resolved)
    return resolved


def safe_child(root: Path, relative: str) -> Path:
    candidate = Path(relative)
    if candidate.is_absolute() or not relative or "\x00" in relative:
        fail(f"unsafe manifest path: {relative!r}")
    joined = root / candidate
    current = root
    for part in candidate.parts:
        if part in {"", ".", ".."}:
            fail(f"unsafe manifest path: {relative!r}")
        current = current / part
        if current.is_symlink():
            fail(f"manifest path contains a symlink: {relative!r}")
    try:
        resolved = joined.resolve(strict=True)
    except OSError as error:
        fail(f"cannot resolve image {relative!r}: {error}")
    if resolved.parent != root or resolved == root:
        fail(f"image must be a direct child of the artifact directory: {relative!r}")
    if not resolved.is_file():
        fail(f"image is not a regular file: {relative!r}")
    check_mode(resolved, 0o600)
    return resolved


def validate_alt(value: Any) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 200:
        fail("each image needs non-empty alt text of at most 200 characters")
    if any(character in value for character in "\r\n[]#") or not value.isprintable():
        fail(f"unsafe alt text: {value!r}")
    return value


def inspect_image(path: Path, expected_format: str) -> tuple[int, int, str]:
    if path.stat().st_size > 10 * 1024 * 1024:
        fail(f"image exceeds the 10 MB attachment limit: {path.name}")
    try:
        with Image.open(path) as image:
            actual_format = image.format
            width, height = image.size
            if (
                width < 32
                or height < 32
                or width > 8192
                or height > 8192
                or width * height > 40_000_000
            ):
                fail(f"image dimensions exceed the safe bounds: {path.name}")
            image.verify()
        with Image.open(path) as image:
            image.load()
            if actual_format != expected_format or image.format != expected_format:
                fail(f"image bytes do not match the extension: {path.name}")
            sample = image.convert("RGB")
            sample.thumbnail((256, 256))
            stats = ImageStat.Stat(sample)
            if max(stats.var) < 0.5 or len(sample.getcolors(maxcolors=65536) or []) < 2:
                fail(f"image appears blank or uniform: {path.name}")
    except (UnidentifiedImageError, OSError, ValueError) as error:
        fail(f"invalid image bytes for {path.name}: {error}")
    return width, height, SUPPORTED_FORMATS[expected_format]


def run_visual_inspector(executable: str, rows: list[ImageRow]) -> None:
    payload = {
        "images": [
            {
                "path": str(row.path),
                "alt": row.alt,
                "width": row.width,
                "height": row.height,
            }
            for row in rows
        ]
    }
    result = subprocess.run(
        [executable],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        fail(f"visual inspector failed: {redact(result.stderr.strip())}")
    try:
        response = json.loads(result.stdout)
    except json.JSONDecodeError:
        fail("visual inspector returned malformed JSON")
    if response != {"ok": True}:
        fail("visual inspector did not approve every image")


def load_manifest(
    root: Path, manifest_path: str, inspector: str | None
) -> list[ImageRow]:
    manifest = safe_child(root, manifest_path)
    if manifest.stat().st_size > 1024 * 1024:
        fail("manifest exceeds 1 MB")
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"malformed manifest: {error}")
    if (
        not isinstance(data, dict)
        or set(data) != {"images"}
        or not isinstance(data["images"], list)
    ):
        fail("manifest must contain only an images array")
    if not data["images"]:
        fail("manifest images array must not be empty")
    rows: list[ImageRow] = []
    paths: set[str] = set()
    alts: set[str] = set()
    for index, item in enumerate(data["images"]):
        if not isinstance(item, dict) or set(item) != {"path", "alt"}:
            fail(f"manifest row {index + 1} must contain only path and alt")
        relative = item["path"]
        if not isinstance(relative, str):
            fail(f"manifest row {index + 1} path must be a string")
        alt = validate_alt(item["alt"])
        if relative in paths or alt in alts:
            fail(f"duplicate manifest row path or alt at row {index + 1}")
        suffix = Path(relative).suffix.lower()
        if suffix not in EXTENSIONS:
            fail(f"unsupported image type: {relative}")
        image_path = safe_child(root, relative)
        width, height, media_type = inspect_image(image_path, EXTENSIONS[suffix])
        rows.append(
            ImageRow(
                path=image_path,
                relative_path=relative,
                alt=alt,
                sha256=hashlib.sha256(image_path.read_bytes()).hexdigest(),
                width=width,
                height=height,
                media_type=media_type,
            )
        )
        paths.add(relative)
        alts.add(alt)
    if inspector:
        run_visual_inspector(inspector, rows)
    return rows


def validate_markers(start: str, end: str) -> None:
    if not start or not end or start == end or "\n" in start or "\n" in end:
        fail("body markers must be distinct, non-empty single lines")
    if not start.startswith("<!--") or not start.endswith("-->"):
        fail("start marker must be an HTML comment")
    if not end.startswith("<!--") or not end.endswith("-->"):
        fail("end marker must be an HTML comment")


def split_region(body: str, start: str, end: str) -> tuple[str, str, str]:
    if body.count(start) != 1 or body.count(end) != 1:
        fail("PR body must contain exactly one start marker and one end marker")
    start_at = body.index(start)
    end_at = body.index(end)
    if end_at <= start_at:
        fail("PR body markers are out of order")
    region_start = start_at + len(start)
    return body[:region_start], body[region_start:end_at], body[end_at:]


def replace_region(body: str, start: str, end: str, content: str) -> str:
    prefix, _, suffix = split_region(body, start, end)
    return prefix + "\n" + content.rstrip("\n") + "\n" + suffix


def validate_url(url: str) -> str:
    if not ASSET_URL_RE.fullmatch(url):
        fail(f"unsafe attachment URL: {url!r}")
    return url


def markdown_for(rows: list[ImageRow], records: dict[str, dict[str, Any]]) -> str:
    lines = []
    for row in rows:
        record = records.get(row.relative_path, {})
        if record.get("sha256") == row.sha256 and record.get("url"):
            target = validate_url(record["url"])
        else:
            target = str(row.path)
        lines.append(f"![{row.alt}]({target})")
    return "\n\n".join(lines)


def load_state(path: Path, repo: str, pr: int, start: str, end: str) -> dict[str, Any]:
    if not path.exists():
        return {
            "version": 1,
            "repo": repo,
            "pr": pr,
            "markers": [start, end],
            "images": {},
        }
    if path.is_symlink():
        fail("upload record must not be a symlink")
    check_mode(path, 0o600)
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"malformed upload record: {error}")
    if not isinstance(state, dict) or state.get("version") != 1:
        fail("unsupported upload record")
    if (state.get("repo"), state.get("pr"), state.get("markers")) != (
        repo,
        pr,
        [start, end],
    ):
        fail("upload record belongs to another PR or marker pair")
    images = state.get("images")
    if not isinstance(images, dict):
        fail("malformed upload record images")
    for record in images.values():
        if not isinstance(record, dict):
            fail("malformed upload record row")
        if record.get("url"):
            validate_url(record["url"])
    return state


def write_state(path: Path, state: dict[str, Any]) -> None:
    descriptor, temporary = tempfile.mkstemp(prefix=STATE_NAME + ".", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(state, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class Gh:
    def __init__(self, executable: str):
        self.executable = executable

    def run(
        self, arguments: list[str], stdin: str | None = None, check: bool = True
    ) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [self.executable, *arguments],
            input=stdin,
            text=True,
            capture_output=True,
            check=False,
        )
        if check and result.returncode != 0:
            detail = redact(result.stderr.strip() or result.stdout.strip())
            fail(f"gh command failed: {detail}")
        return result

    def supports_attachments(self) -> bool:
        result = self.run(["pr", "edit", "--help"], check=False)
        return (
            result.returncode == 0
            and re.search(r"(?m)^\s+--attach(?:\s|$)", result.stdout) is not None
        )

    def body(self, repo: str, pr: int) -> str:
        result = self.run(["pr", "view", str(pr), "--repo", repo, "--json", "body"])
        try:
            value = json.loads(result.stdout)["body"]
        except (json.JSONDecodeError, KeyError, TypeError):
            fail("gh returned a malformed PR body response")
        if not isinstance(value, str):
            fail("gh returned a non-text PR body")
        return value

    def visibility(self, repo: str) -> str:
        result = self.run(["repo", "view", repo, "--json", "visibility"])
        try:
            value = json.loads(result.stdout)["visibility"]
        except (json.JSONDecodeError, KeyError, TypeError):
            fail("gh returned a malformed repository visibility response")
        if value not in {"PUBLIC", "PRIVATE", "INTERNAL"}:
            fail("gh returned an unknown repository visibility")
        return value


def extract_urls(region: str, rows: list[ImageRow]) -> dict[str, str]:
    found: dict[str, str] = {}
    for row in rows:
        match = re.search(rf"!\[{re.escape(row.alt)}\]\(([^)]+)\)", region)
        if match and ASSET_URL_RE.fullmatch(match.group(1)):
            found[row.relative_path] = match.group(1)
    return found


def verify_anonymous(url: str, visibility: str) -> str:
    request = urllib.request.Request(
        url, method="HEAD", headers={"User-Agent": "pr-review-media/1"}
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status = response.status
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
    except urllib.error.URLError as error:
        fail(f"anonymous attachment check failed: {error.reason}")
    if visibility == "PUBLIC" and not 200 <= status < 400:
        fail(f"public attachment is not anonymously readable: HTTP {status}")
    if visibility != "PUBLIC" and 200 <= status < 400:
        fail("private or internal attachment is anonymously readable")
    return f"HTTP {status}"


def report(
    rows: list[ImageRow], attachment_support: bool, inspector: bool
) -> dict[str, Any]:
    return {
        "status": "dry-run",
        "attachment_support": "official-gh" if attachment_support else "unsupported",
        "visual_inspection": "configured" if inspector else "built-in-content-check",
        "images": [
            {
                "path": row.relative_path,
                "sha256": row.sha256,
                "width": row.width,
                "height": row.height,
                "media_type": row.media_type,
            }
            for row in rows
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="GitHub OWNER/REPO")
    parser.add_argument("--pr", required=True, type=int, help="pull request number")
    parser.add_argument(
        "--artifact-dir", required=True, help="absolute 0700 artifact directory"
    )
    parser.add_argument(
        "--manifest",
        required=True,
        help="manifest filename inside the artifact directory",
    )
    parser.add_argument("--marker-start", default=DEFAULT_START)
    parser.add_argument("--marker-end", default=DEFAULT_END)
    parser.add_argument(
        "--visual-inspector", default=os.environ.get("PR_REVIEW_MEDIA_VISUAL_INSPECTOR")
    )
    parser.add_argument(
        "--approve-writes",
        action="store_true",
        help="allow attachment uploads and one PR body edit",
    )
    return parser.parse_args()


def main() -> int:
    try:
        arguments = parse_args()
        if not REPO_RE.fullmatch(arguments.repo):
            fail("repo must have the form OWNER/REPO")
        if arguments.pr < 1:
            fail("PR number must be positive")
        validate_markers(arguments.marker_start, arguments.marker_end)
        root = validate_artifact_dir(arguments.artifact_dir)
        rows = load_manifest(root, arguments.manifest, arguments.visual_inspector)
        gh = Gh(os.environ.get("PR_REVIEW_MEDIA_GH", "gh"))
        supported = gh.supports_attachments()
        state_path = root / STATE_NAME
        state = load_state(
            state_path,
            arguments.repo,
            arguments.pr,
            arguments.marker_start,
            arguments.marker_end,
        )
        if not arguments.approve_writes:
            print(
                json.dumps(
                    report(rows, supported, bool(arguments.visual_inspector)),
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        if not supported:
            fail(
                "unsupported: this gh release has no official 'gh pr edit --attach' mechanism; no upload or body change was made"
            )
        records = state["images"]
        for row in rows:
            prior = records.get(row.relative_path, {})
            if prior.get("sha256") != row.sha256:
                records[row.relative_path] = {"sha256": row.sha256, "status": "pending"}
        write_state(state_path, state)

        before = gh.body(arguments.repo, arguments.pr)
        prefix, _, suffix = split_region(
            before, arguments.marker_start, arguments.marker_end
        )
        desired = markdown_for(rows, records)
        updated = replace_region(
            before, arguments.marker_start, arguments.marker_end, desired
        )
        pending = [row for row in rows if not records[row.relative_path].get("url")]
        command = [
            "pr",
            "edit",
            str(arguments.pr),
            "--repo",
            arguments.repo,
            "--body-file",
            "-",
        ]
        for row in pending:
            command.extend(["--attach", f"{row.path}#{row.alt}"])
        result = gh.run(command, stdin=updated, check=False)

        after = gh.body(arguments.repo, arguments.pr)
        after_prefix, region, after_suffix = split_region(
            after, arguments.marker_start, arguments.marker_end
        )
        if after_prefix != prefix or after_suffix != suffix:
            fail("gh changed bytes outside the managed PR body region")
        uploaded = extract_urls(region, rows)
        for row in rows:
            if row.relative_path in uploaded:
                records[row.relative_path] = {
                    "sha256": row.sha256,
                    "status": "uploaded",
                    "url": validate_url(uploaded[row.relative_path]),
                }
            elif not records[row.relative_path].get("url"):
                records[row.relative_path]["status"] = "pending"
        write_state(state_path, state)

        if result.returncode != 0:
            detail = redact(result.stderr.strip() or result.stdout.strip())
            fail(
                f"gh reported a partial or failed upload; resume with the same command: {detail}"
            )
        missing = [
            row.relative_path
            for row in rows
            if not records[row.relative_path].get("url")
        ]
        if missing:
            fail("gh completed without safe attachment URLs for: " + ", ".join(missing))

        visibility = gh.visibility(arguments.repo)
        anonymous = {
            row.relative_path: verify_anonymous(
                records[row.relative_path]["url"], visibility
            )
            for row in rows
        }
        print(
            json.dumps(
                {
                    "status": "updated",
                    "repo": arguments.repo,
                    "pr": arguments.pr,
                    "visibility": visibility,
                    "anonymous_checks": anonymous,
                    "images": records,
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 0
    except MediaError as error:
        print(f"pr-review-media: {redact(str(error))}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
