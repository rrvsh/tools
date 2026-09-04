#!/usr/bin/env python3
"""Create a deterministic, read-only health report for a Markdown memory tree."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import stat
import sys
import tempfile
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path
from urllib.parse import unquote, urlparse

MARKDOWN_LINK = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+[^)]*)?\)")
INDEX_PATH = re.compile(r"`([A-Za-z0-9_~@+./:-]+\.md(?:#[^`\s]+)?)`")
DATE = re.compile(r"\b(20\d{2}-\d{2}-\d{2})\b")
FULL_PR = re.compile(
    r"https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/pull/(\d+)"
)
NAMED_PR = re.compile(
    r"\b([A-Za-z0-9_.-]+)\s+(?:PR|pull request)\s+#(\d+)\b", re.IGNORECASE
)
CONFLICT_NAME = re.compile(r"(?:sync-conflict|\.conflict-)", re.IGNORECASE)
DATED_NAME = re.compile(r"^20\d{2}-\d{2}-\d{2}-.+\.md$")
SECRET_PATTERNS = {
    "private-key-marker": re.compile(r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----"),
    "github-token": re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"),
    "provider-key": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
    "secret-assignment": re.compile(
        r"(?i)\b(?:api[_ -]?key|access[_ -]?token|auth(?:orization)?|password|secret|token)\b"
        r"\s*[:=]\s*(?!\$\{|<|\[?redacted\b|none\b|null\b)[\"']?[^\s\"']+"
    ),
}


def tree_hash(root: Path) -> str:
    digest = hashlib.sha256()
    if not root.exists():
        digest.update(b"missing\0")
        return digest.hexdigest()
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(root).as_posix()
        metadata = path.lstat()
        digest.update(relative.encode("utf-8", "surrogateescape") + b"\0")
        digest.update(oct(stat.S_IMODE(metadata.st_mode)).encode() + b"\0")
        if path.is_symlink():
            digest.update(
                b"link\0" + os.readlink(path).encode("utf-8", "surrogateescape")
            )
        elif path.is_file():
            digest.update(b"file\0")
            with path.open("rb") as source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(block)
        elif path.is_dir():
            digest.update(b"dir\0")
        else:
            digest.update(b"other\0")
        digest.update(b"\0")
    return digest.hexdigest()


def location(path: Path, line: int | None, base: Path) -> dict[str, object]:
    try:
        display = path.relative_to(base).as_posix()
    except ValueError:
        display = path.name
    result: dict[str, object] = {"path": display}
    if line is not None:
        result["line"] = line
    return result


def markdown_files(memory_root: Path, index_path: Path) -> list[Path]:
    files = (
        [
            path
            for path in memory_root.rglob("*.md")
            if path.is_file() and not path.is_symlink()
        ]
        if memory_root.is_dir()
        else []
    )
    if index_path.is_file() and not index_path.is_symlink() and index_path not in files:
        files.append(index_path)
    return sorted(files, key=lambda item: item.as_posix())


def resolve_local_reference(
    source: Path, target: str, agents_root: Path
) -> Path | None:
    target = unquote(target.split("#", 1)[0])
    if not target or target.startswith(("#", "mailto:")):
        return None
    parsed = urlparse(target)
    if parsed.scheme or parsed.netloc:
        return None
    if target.startswith("~/"):
        return Path(target).expanduser()
    if target.startswith("memory/"):
        return (agents_root / target).resolve()
    candidate = Path(target)
    return (
        candidate if candidate.is_absolute() else (source.parent / candidate).resolve()
    )


def load_github_states(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or any(
        not isinstance(key, str) or not isinstance(value, str)
        for key, value in data.items()
    ):
        raise ValueError(
            "GitHub state file must contain a string-to-string JSON object"
        )
    return {key.lower(): value.lower() for key, value in data.items()}


def fetch_pr_state(reference: str, timeout: float) -> tuple[str, str | None]:
    repository, number = reference.rsplit("#", 1)
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/pulls/{number}",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "memory-health-audit/1",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.load(response)
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as error:
        return "unknown", type(error).__name__
    if payload.get("merged_at"):
        return "merged", None
    return str(payload.get("state", "unknown")).lower(), None


def audit(args: argparse.Namespace) -> dict[str, object]:
    memory_root = args.memory_root.resolve()
    index_path = args.index.resolve()
    agents_root = memory_root.parent
    before = tree_hash(memory_root)
    files = markdown_files(memory_root, index_path)
    findings: dict[str, list[dict[str, object]]] = {
        "broken_references": [],
        "missing_indexed_files": [],
        "duplicate_index_entries": [],
        "conflict_copies": [],
        "stale_todos": [],
        "github_pr_references": [],
        "secret_patterns": [],
        "duplicate_candidates": [],
        "misplaced_candidates": [],
    }
    contents: dict[Path, str] = {}
    indexed: defaultdict[str, list[dict[str, object]]] = defaultdict(list)
    pr_locations: defaultdict[str, list[dict[str, object]]] = defaultdict(list)
    content_hashes: defaultdict[str, list[Path]] = defaultdict(list)
    today = args.today or dt.datetime.now(dt.timezone.utc).date()
    stale_before = today - dt.timedelta(days=args.stale_days)

    if memory_root.is_dir():
        for path in sorted(memory_root.rglob("*"), key=lambda item: item.as_posix()):
            if CONFLICT_NAME.search(path.name):
                findings["conflict_copies"].append(location(path, None, agents_root))

    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        contents[path] = text
        if path.is_relative_to(memory_root):
            content_hashes[hashlib.sha256(text.encode("utf-8")).hexdigest()].append(
                path
            )
            relative = path.relative_to(memory_root)
            if DATED_NAME.match(path.name) and (
                not relative.parts or relative.parts[0] != "logs"
            ):
                findings["misplaced_candidates"].append(
                    {
                        **location(path, None, agents_root),
                        "reason": "dated-file-outside-logs",
                    }
                )
            if (
                relative.parts
                and relative.parts[0] == "logs"
                and not DATED_NAME.match(path.name)
            ):
                findings["misplaced_candidates"].append(
                    {
                        **location(path, None, agents_root),
                        "reason": "undated-file-in-logs",
                    }
                )
        for line_number, line in enumerate(text.splitlines(), 1):
            line_targets = sorted(
                set(MARKDOWN_LINK.findall(line) + INDEX_PATH.findall(line))
            )
            for raw_target in line_targets:
                target = resolve_local_reference(path, raw_target, agents_root)
                if target is not None and not target.exists():
                    findings["broken_references"].append(
                        {
                            **location(path, line_number, agents_root),
                            "target": raw_target.split("#", 1)[0],
                        }
                    )
            if path == index_path:
                for raw_target in line_targets:
                    target = resolve_local_reference(path, raw_target, agents_root)
                    if target is None:
                        continue
                    try:
                        relative_target = target.relative_to(memory_root).as_posix()
                    except ValueError:
                        continue
                    indexed[relative_target].append(
                        location(path, line_number, agents_root)
                    )
            if path.name.lower() == "todo.md" or "todo" in line.lower():
                for raw_date in DATE.findall(line):
                    parsed_date = dt.date.fromisoformat(raw_date)
                    if parsed_date < stale_before:
                        findings["stale_todos"].append(
                            {
                                **location(path, line_number, agents_root),
                                "date": raw_date,
                                "age_days": (today - parsed_date).days,
                            }
                        )
            for owner, repository, number in FULL_PR.findall(line):
                pr_locations[f"{owner}/{repository}#{number}".lower()].append(
                    location(path, line_number, agents_root)
                )
            for repository, number in NAMED_PR.findall(line):
                pr_locations[
                    f"{args.github_owner}/{repository}#{number}".lower()
                ].append(location(path, line_number, agents_root))
            for category, pattern in SECRET_PATTERNS.items():
                if pattern.search(line):
                    findings["secret_patterns"].append(
                        {
                            **location(path, line_number, agents_root),
                            "category": category,
                            "value": "[REDACTED]",
                        }
                    )

    for target, locations in sorted(indexed.items()):
        if len(locations) > 1:
            findings["duplicate_index_entries"].append(
                {"target": f"memory/{target}", "locations": locations}
            )
        if not (memory_root / target).is_file():
            findings["missing_indexed_files"].append(
                {"target": f"memory/{target}", "locations": locations}
            )

    for paths in content_hashes.values():
        if len(paths) > 1:
            findings["duplicate_candidates"].append(
                {
                    "reason": "exact-content",
                    "paths": [
                        location(path, None, agents_root)["path"] for path in paths
                    ],
                }
            )

    states = load_github_states(args.github_state_file)
    github_errors: list[dict[str, str]] = []
    github_mode = (
        "local-state"
        if args.github_state_file
        else "online"
        if args.github_online
        else "offline"
    )
    for reference, locations in sorted(pr_locations.items()):
        state = states.get(reference, "unknown")
        if args.github_online and reference not in states:
            state, error = fetch_pr_state(reference, args.github_timeout)
            if error:
                github_errors.append({"reference": reference, "error": error})
        findings["github_pr_references"].append(
            {
                "reference": reference,
                "state": state,
                "stale": state in {"closed", "merged"},
                "locations": locations,
            }
        )

    after = tree_hash(memory_root)
    return {
        "schema_version": 1,
        "generated_at": args.generated_at.isoformat(),
        "memory_root": str(memory_root),
        "index_path": str(index_path),
        "github": {"mode": github_mode, "errors": github_errors},
        "source_tree": {
            "before_sha256": before,
            "after_sha256": after,
            "unchanged": before == after,
        },
        "counts": {key: len(value) for key, value in findings.items()},
        "findings": findings,
    }


def markdown_report(result: dict[str, object]) -> str:
    counts = result["counts"]
    source = result["source_tree"]
    github = result["github"]
    findings = result["findings"]
    lines = [
        "# Memory health audit",
        "",
        f"- Generated: `{result['generated_at']}`",
        f"- GitHub check: `{github['mode']}`",
        f"- Source hash before: `{source['before_sha256']}`",
        f"- Source hash after: `{source['after_sha256']}`",
        f"- Source unchanged: `{str(source['unchanged']).lower()}`",
        "",
        "## Counts",
        "",
    ]
    for category, count in counts.items():
        lines.append(f"- {category.replace('_', ' ')}: {count}")
    lines.extend(["", "## Findings", ""])
    for category, entries in findings.items():
        lines.append(f"### {category.replace('_', ' ').title()}")
        lines.append("")
        if not entries:
            lines.append("- None.")
        else:
            for entry in entries:
                lines.append(
                    f"- `{json.dumps(entry, sort_keys=True, separators=(',', ':'))}`"
                )
        lines.append("")
    lines.extend(
        [
            "## Privacy",
            "",
            "- The report contains paths, line numbers, states, dates, categories, and hashes.",
            "- Secret-like values are `[REDACTED]`.",
            "- The report does not copy matched private prose.",
            "- The audit does not edit the memory tree.",
            "",
        ]
    )
    return "\n".join(lines)


def write_private(path: Path, data: str) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as destination:
            destination.write(data)
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    home = Path.home()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--memory-root", type=Path, default=home / "Agents/memory")
    parser.add_argument("--index", type=Path, default=home / "Agents/MEMORY.md")
    parser.add_argument(
        "--output-dir", type=Path, default=home / "Agents/research/memory-audit"
    )
    parser.add_argument("--stale-days", type=int, default=90)
    parser.add_argument("--today", type=dt.date.fromisoformat)
    parser.add_argument("--generated-at", type=dt.datetime.fromisoformat)
    parser.add_argument("--github-owner", default="rrvsh")
    parser.add_argument(
        "--github-state-file",
        type=Path,
        help="Read PR states from a local JSON fixture",
    )
    github = parser.add_mutually_exclusive_group()
    github.add_argument(
        "--github-online", action="store_true", help="Query GitHub for PR states"
    )
    github.add_argument(
        "--offline", action="store_true", help="Do not query GitHub (the default)"
    )
    parser.add_argument("--github-timeout", type=float, default=10.0)
    args = parser.parse_args(argv)
    if args.stale_days < 0:
        parser.error("--stale-days must be zero or greater")
    memory_root = args.memory_root.resolve()
    output_dir = args.output_dir.resolve()
    if output_dir == memory_root or output_dir.is_relative_to(memory_root):
        parser.error("--output-dir must be outside --memory-root")
    if args.generated_at is None:
        args.generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    elif args.generated_at.tzinfo is None:
        args.generated_at = args.generated_at.replace(tzinfo=dt.timezone.utc)
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    result = audit(args)
    stamp = args.generated_at.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
    markdown_path = args.output_dir / f"{stamp}.md"
    json_path = args.output_dir / f"{stamp}.json"
    write_private(markdown_path, markdown_report(result))
    write_private(json_path, json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(markdown_path)
    print(json_path)
    if not result["source_tree"]["unchanged"]:
        print("memory tree changed during the audit", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
