#!/usr/bin/env python3
"""Inspect and reconcile a bounded GitHub pull request stack."""

from __future__ import annotations

import argparse
import dataclasses
import fnmatch
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import uuid
from pathlib import Path, PurePosixPath
from typing import Any, Sequence

SCHEMA_VERSION = 1
MARKER_NAME = ".pr-stack-reconcile-owner.json"
CREDENTIAL_PATTERNS = (
    re.compile(r"github_pat_[A-Za-z0-9_]+"),
    re.compile(r"gh[opusr]_[A-Za-z0-9]{20,}"),
    re.compile(r"\bBearer\s+\S+", re.IGNORECASE),
    re.compile(
        r"(?:password|passwd|secret|token|cookie|authorization)\s*[=:]\s*\S+",
        re.IGNORECASE,
    ),
    re.compile(r"[a-z][a-z0-9+.-]*://[^/@\s:]+:[^/@\s]+@", re.IGNORECASE),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
)
SENSITIVE_ENV_PARTS = (
    "TOKEN",
    "SECRET",
    "PASSWORD",
    "PASSWD",
    "COOKIE",
    "AUTH",
    "PRIVATE_KEY",
)


class ReconcileError(RuntimeError):
    """A safe refusal with no secret-bearing subprocess output."""


@dataclasses.dataclass(frozen=True)
class BranchSpec:
    name: str
    old_sha: str
    old_parent_sha: str


@dataclasses.dataclass(frozen=True)
class Config:
    repo: Path
    github_repo: str
    remote: str
    base_branch: str
    base_sha: str
    branches: tuple[BranchSpec, ...]
    allowed_paths: tuple[str, ...]
    validation_commands: tuple[str, ...]
    lockfile_command: str
    tmp_root: Path

    def public_dict(self) -> dict[str, Any]:
        return {
            "repo": str(self.repo),
            "github_repo": self.github_repo,
            "remote": self.remote,
            "base_branch": self.base_branch,
            "base_sha": self.base_sha,
            "branches": [dataclasses.asdict(branch) for branch in self.branches],
            "allowed_paths": list(self.allowed_paths),
            "validation_command_sha256": [
                digest_text(command) for command in self.validation_commands
            ],
            "lockfile_command_sha256": digest_text(self.lockfile_command),
            "tmp_root": str(self.tmp_root),
        }


@dataclasses.dataclass
class CommandResult:
    stdout: str
    stderr: str
    returncode: int


def digest_text(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def contains_credential(value: str) -> bool:
    return any(pattern.search(value) for pattern in CREDENTIAL_PATTERNS)


def safe_environment(*, github: bool = False) -> dict[str, str]:
    environment = {
        key: value
        for key, value in os.environ.items()
        if github or not any(part in key.upper() for part in SENSITIVE_ENV_PARTS)
    }
    environment.setdefault("PATH", os.defpath)
    return environment


def run(
    command: Sequence[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    github: bool = False,
    environment: dict[str, str] | None = None,
) -> CommandResult:
    if any(contains_credential(part) for part in command):
        raise ReconcileError(
            "refused a command argument that appears to contain a credential"
        )
    completed = subprocess.run(
        list(command),
        cwd=cwd,
        env=environment or safe_environment(github=github),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if contains_credential(completed.stdout) or contains_credential(completed.stderr):
        raise ReconcileError(
            "a subprocess emitted content that appears to contain a credential"
        )
    result = CommandResult(completed.stdout, completed.stderr, completed.returncode)
    if check and result.returncode:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[-1]}" if detail else ""
        raise ReconcileError(
            f"command failed with exit code {result.returncode}{suffix}"
        )
    return result


def git(repo: Path, *arguments: str, check: bool = True) -> CommandResult:
    return run(("git", "-C", str(repo), *arguments), check=check)


def require_gh_authentication() -> None:
    executable = os.environ.get("PR_STACK_RECONCILE_GH", "gh")
    run((executable, "auth", "status", "--active"), github=True)


def gh(*arguments: str) -> Any:
    executable = os.environ.get("PR_STACK_RECONCILE_GH", "gh")
    result = run((executable, *arguments), github=True)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise ReconcileError("GitHub CLI returned invalid JSON") from error


def normalize_allowed_path(raw: str) -> str:
    value = raw.strip().replace("\\", "/")
    path = PurePosixPath(value)
    if not value or value.startswith("/") or ".." in path.parts or "." in path.parts:
        raise argparse.ArgumentTypeError(
            "allowed paths must be normalized repository-relative paths"
        )
    return value.rstrip("/")


def validate_sha(raw: str, field: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{40}", raw):
        raise argparse.ArgumentTypeError(f"{field} must be a full lowercase commit SHA")
    return raw


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "phase", choices=("inspect", "prepare", "rebase", "verify", "push", "cleanup")
    )
    parser.add_argument("--repo", required=True, help="explicit stable checkout path")
    parser.add_argument("--github-repo", required=True, help="explicit OWNER/REPO")
    parser.add_argument("--remote", required=True, help="explicit Git remote name")
    parser.add_argument("--base-branch", required=True)
    parser.add_argument("--expected-base-sha", required=True)
    parser.add_argument(
        "--branch",
        action="append",
        required=True,
        metavar="NAME:OLD_SHA:OLD_PARENT_SHA",
        help="ordered root-to-leaf branch specification",
    )
    parser.add_argument("--allowed-path", action="append", required=True)
    parser.add_argument("--validation-command", action="append", required=True)
    parser.add_argument("--lockfile-command", required=True)
    parser.add_argument("--tmp-root", required=True)
    parser.add_argument(
        "--target", help="one declared branch for rebase, verify, or push"
    )
    parser.add_argument(
        "--expected-new-parent-sha", help="exact new parent for rebase or verify"
    )
    parser.add_argument(
        "--apply-rebase", action="store_true", help="permit a rebase side effect"
    )
    parser.add_argument(
        "--apply-push", action="store_true", help="permit a push side effect"
    )
    return parser


def parse_config(args: argparse.Namespace) -> Config:
    argv_text = "\n".join(sys.argv[1:])
    if contains_credential(argv_text):
        raise ReconcileError("refused arguments that appear to contain a credential")

    repo = Path(args.repo).expanduser().resolve(strict=True)
    if not (repo / ".git").exists():
        raise ReconcileError("--repo must name an explicit Git worktree root")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.github_repo):
        raise ReconcileError("--github-repo must have the exact OWNER/REPO form")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.remote):
        raise ReconcileError("--remote is invalid")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", args.base_branch):
        raise ReconcileError("--base-branch is invalid")
    base_sha = validate_sha(args.expected_base_sha, "--expected-base-sha")

    branches: list[BranchSpec] = []
    names: set[str] = set()
    for raw in args.branch:
        values = raw.split(":", 2)
        if len(values) != 3 or any(not value for value in values):
            raise argparse.ArgumentTypeError(
                "--branch must contain three non-empty fields"
            )
        name, old_sha, old_parent_sha = values
        if run(("git", "check-ref-format", "--branch", name), check=False).returncode:
            raise ReconcileError(f"invalid branch name: {name}")
        if name in names or name == args.base_branch:
            raise ReconcileError(
                "branch names must be unique and must not equal the base branch"
            )
        names.add(name)
        branches.append(
            BranchSpec(
                name=name,
                old_sha=validate_sha(old_sha, "branch old SHA"),
                old_parent_sha=validate_sha(old_parent_sha, "branch old parent SHA"),
            )
        )
    if len(branches) > 8:
        raise ReconcileError("refused a stack larger than eight branches")

    allowed_paths = tuple(normalize_allowed_path(path) for path in args.allowed_path)
    commands = (*args.validation_command, args.lockfile_command)
    if any(not command.strip() for command in commands):
        raise ReconcileError("validation commands must not be empty")
    if any(contains_credential(command) for command in commands):
        raise ReconcileError(
            "refused a validation command that appears to contain a credential"
        )

    tmp_root = Path(args.tmp_root)
    if (
        not tmp_root.is_absolute()
        or tmp_root.parent != Path("/tmp")
        or tmp_root.name in ("", ".", "..")
    ):
        raise ReconcileError("--tmp-root must be a direct child of /tmp")
    if tmp_root.is_symlink():
        raise ReconcileError("--tmp-root must not be a symbolic link")

    return Config(
        repo=repo,
        github_repo=args.github_repo,
        remote=args.remote,
        base_branch=args.base_branch,
        base_sha=base_sha,
        branches=tuple(branches),
        allowed_paths=allowed_paths,
        validation_commands=tuple(args.validation_command),
        lockfile_command=args.lockfile_command,
        tmp_root=tmp_root,
    )


def require_clean_stable_checkout(config: Config) -> None:
    if git(config.repo, "status", "--porcelain=v1", "--untracked-files=all").stdout:
        raise ReconcileError("stable checkout is dirty")
    common_dir = Path(
        git(
            config.repo, "rev-parse", "--path-format=absolute", "--git-common-dir"
        ).stdout.strip()
    )
    if not common_dir.exists():
        raise ReconcileError("Git common directory is missing")


def worktree_states(config: Config) -> list[dict[str, Any]]:
    lines = git(config.repo, "worktree", "list", "--porcelain").stdout.splitlines()
    states: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for line in lines:
        if line.startswith("worktree "):
            if current:
                states.append(current)
            path = Path(line.removeprefix("worktree ")).resolve()
            current = {
                "path": str(path),
                "dirty": (
                    bool(
                        git(
                            path,
                            "status",
                            "--porcelain=v1",
                            "--untracked-files=all",
                        ).stdout
                    )
                    if path.is_dir()
                    else None
                ),
            }
        elif current and line.startswith("HEAD "):
            current["head"] = line.removeprefix("HEAD ")
        elif current and line.startswith("branch "):
            current["branch"] = line.removeprefix("branch refs/heads/")
        elif current and line == "detached":
            current["branch"] = None
    if current:
        states.append(current)
    return states


def remote_url(config: Config) -> str:
    result = git(config.repo, "remote", "get-url", config.remote)
    value = result.stdout.strip()
    if not value or contains_credential(value):
        raise ReconcileError("remote URL is missing or contains credentials")
    return value


def require_remote_identity(config: Config) -> None:
    value = remote_url(config)
    patterns = (
        r"git@github\.com:(?P<repo>[^/]+/[^/]+?)(?:\.git)?$",
        r"ssh://git@github\.com/(?P<repo>[^/]+/[^/]+?)(?:\.git)?$",
        r"https://github\.com/(?P<repo>[^/]+/[^/]+?)(?:\.git)?/?$",
    )
    matches = [match for pattern in patterns if (match := re.fullmatch(pattern, value))]
    if matches:
        if matches[0].group("repo").lower() != config.github_repo.lower():
            raise ReconcileError(
                "Git remote and --github-repo identify different repositories"
            )
        return
    if os.environ.get("PR_STACK_RECONCILE_GH"):
        return
    raise ReconcileError("remote URL must identify the explicit GitHub repository")


def remote_sha(config: Config, branch: str, *, repository: Path | None = None) -> str:
    if repository is None:
        command = (
            "git",
            "ls-remote",
            "--exit-code",
            remote_url(config),
            f"refs/heads/{branch}",
        )
        result = run(command)
    else:
        result = git(
            repository, "ls-remote", "--exit-code", "origin", f"refs/heads/{branch}"
        )
    lines = [line for line in result.stdout.splitlines() if line]
    if len(lines) != 1:
        raise ReconcileError(f"missing or ambiguous remote ref: {branch}")
    sha, ref = lines[0].split("\t", 1)
    if ref != f"refs/heads/{branch}" or not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ReconcileError(f"invalid remote ref result: {branch}")
    return sha


def require_local_commit(config: Config, sha: str) -> None:
    if git(config.repo, "cat-file", "-e", f"{sha}^{{commit}}", check=False).returncode:
        raise ReconcileError(
            f"required commit is absent from the local object store: {sha}"
        )


def changed_paths(repository: Path, parent: str, tip: str) -> list[str]:
    output = git(
        repository, "diff", "--name-only", "--no-renames", f"{parent}..{tip}"
    ).stdout
    return sorted(path for path in output.splitlines() if path)


def path_is_allowed(path: str, allowed_paths: Sequence[str]) -> bool:
    normalized = PurePosixPath(path)
    if path.startswith("/") or ".." in normalized.parts:
        return False
    return any(
        fnmatch.fnmatchcase(path, allowed)
        or (
            not any(character in allowed for character in "*?[")
            and path.startswith(f"{allowed}/")
        )
        for allowed in allowed_paths
    )


def github_prs(config: Config) -> list[dict[str, Any]]:
    fields = "number,title,url,headRefName,headRefOid,baseRefName,isDraft,mergeable,mergeStateStatus,state"
    selected: list[dict[str, Any]] = []
    for index, branch in enumerate(config.branches):
        data = gh(
            "pr",
            "list",
            "--repo",
            config.github_repo,
            "--head",
            branch.name,
            "--state",
            "open",
            "--limit",
            "2",
            "--json",
            fields,
        )
        if not isinstance(data, list):
            raise ReconcileError("GitHub CLI returned a non-list PR graph")
        matches = [item for item in data if item.get("headRefName") == branch.name]
        if len(matches) != 1:
            raise ReconcileError(
                f"expected exactly one open PR for branch: {branch.name}"
            )
        item = matches[0]
        expected_base = (
            config.base_branch if index == 0 else config.branches[index - 1].name
        )
        if item.get("baseRefName") != expected_base:
            raise ReconcileError(f"ambiguous PR graph for branch: {branch.name}")
        selected.append({key: item.get(key) for key in sorted(item)})
    return selected


def inspect(config: Config) -> dict[str, Any]:
    require_clean_stable_checkout(config)
    require_remote_identity(config)
    require_gh_authentication()
    require_local_commit(config, config.base_sha)
    if remote_sha(config, config.base_branch) != config.base_sha:
        raise ReconcileError("remote base SHA differs from --expected-base-sha")

    reports: list[dict[str, Any]] = []
    for index, branch in enumerate(config.branches):
        require_local_commit(config, branch.old_sha)
        require_local_commit(config, branch.old_parent_sha)
        if remote_sha(config, branch.name) != branch.old_sha:
            raise ReconcileError(
                f"remote branch SHA differs from the declared old SHA: {branch.name}"
            )
        if index > 0 and branch.old_parent_sha != config.branches[index - 1].old_sha:
            raise ReconcileError(
                f"declared stack parent does not match the prior branch tip: {branch.name}"
            )
        merge_base = git(
            config.repo, "merge-base", branch.old_parent_sha, branch.old_sha
        ).stdout.strip()
        if merge_base != branch.old_parent_sha:
            raise ReconcileError(
                f"old parent is not an ancestor of branch: {branch.name}"
            )
        paths = changed_paths(config.repo, branch.old_parent_sha, branch.old_sha)
        unexpected = [
            path for path in paths if not path_is_allowed(path, config.allowed_paths)
        ]
        if unexpected:
            raise ReconcileError(
                f"unexpected changed paths in branch {branch.name}: {', '.join(unexpected)}"
            )
        reports.append(
            {
                "name": branch.name,
                "old_sha": branch.old_sha,
                "old_parent_sha": branch.old_parent_sha,
                "merge_base": merge_base,
                "changed_paths": paths,
            }
        )

    return {
        "phase": "inspect",
        "schema_version": SCHEMA_VERSION,
        "config": config.public_dict(),
        "branches": reports,
        "pull_requests": github_prs(config),
        "stable_checkout_clean": True,
        "worktrees": worktree_states(config),
    }


def config_fingerprint(config: Config) -> str:
    data = config.public_dict().copy()
    data.pop("tmp_root")
    return digest_text(json.dumps(data, sort_keys=True, separators=(",", ":")))


def marker_path(config: Config) -> Path:
    return config.tmp_root / MARKER_NAME


def load_manifest(config: Config) -> dict[str, Any]:
    path = marker_path(config)
    if not path.is_file() or path.is_symlink():
        raise ReconcileError("command ownership marker is missing")
    try:
        manifest = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ReconcileError("command ownership marker is invalid") from error
    if (
        manifest.get("schema_version") != SCHEMA_VERSION
        or manifest.get("owner") != "pr-stack-reconcile"
        or manifest.get("config_fingerprint") != config_fingerprint(config)
    ):
        raise ReconcileError("command ownership marker does not match these arguments")
    return manifest


def save_manifest(config: Config, manifest: dict[str, Any]) -> None:
    path = marker_path(config)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    os.chmod(temporary, stat.S_IRUSR | stat.S_IWUSR)
    os.replace(temporary, path)


def prepare(config: Config) -> dict[str, Any]:
    inspected = inspect(config)
    if config.tmp_root.exists():
        raise ReconcileError("--tmp-root already exists")
    os.mkdir(config.tmp_root, mode=0o700)
    manifest: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "owner": "pr-stack-reconcile",
        "ownership_id": str(uuid.uuid4()),
        "config_fingerprint": config_fingerprint(config),
        "repository": "repository.git",
        "worktrees": {},
        "current_shas": {branch.name: branch.old_sha for branch in config.branches},
        "pushed_shas": {},
        "verified": {},
    }
    save_manifest(config, manifest)
    repository = config.tmp_root / "repository.git"
    try:
        run(("git", "clone", "--mirror", remote_url(config), str(repository)))
        git(repository, "config", "remote.origin.mirror", "false")
        for key in ("user.name", "user.email"):
            value = git(config.repo, "config", "--get", key, check=False).stdout.strip()
            if not value or contains_credential(value):
                raise ReconcileError(f"stable checkout has no safe {key} value")
            git(repository, "config", key, value)
        git(repository, "config", "commit.gpgSign", "false")
        if (
            remote_sha(config, config.base_branch, repository=repository)
            != config.base_sha
        ):
            raise ReconcileError("remote base changed during preparation")
        worktrees_root = config.tmp_root / "worktrees"
        worktrees_root.mkdir(mode=0o700)
        for index, branch in enumerate(config.branches):
            if remote_sha(config, branch.name, repository=repository) != branch.old_sha:
                raise ReconcileError(
                    f"remote branch changed during preparation: {branch.name}"
                )
            path = worktrees_root / f"{index + 1:02d}-{branch.name.replace('/', '--')}"
            manifest["worktrees"][branch.name] = str(path.relative_to(config.tmp_root))
            save_manifest(config, manifest)
            git(repository, "worktree", "add", "--detach", str(path), branch.old_sha)
            git(path, "switch", branch.name)
    except BaseException:
        # Keep the marker and partial state so cleanup can recover it.
        raise
    return {
        "phase": "prepare",
        "schema_version": SCHEMA_VERSION,
        "tmp_root": str(config.tmp_root),
        "ownership_id": manifest["ownership_id"],
        "worktrees": manifest["worktrees"],
        "inspect": inspected,
    }


def target_branch(config: Config, target: str | None) -> BranchSpec:
    if not target:
        raise ReconcileError("--target is required for this phase")
    matches = [branch for branch in config.branches if branch.name == target]
    if len(matches) != 1:
        raise ReconcileError("--target must name one declared branch")
    return matches[0]


def owned_worktree(
    config: Config, manifest: dict[str, Any], branch: BranchSpec
) -> Path:
    relative = manifest.get("worktrees", {}).get(branch.name)
    if not isinstance(relative, str):
        raise ReconcileError(f"manifest has no worktree for branch: {branch.name}")
    path = (config.tmp_root / relative).resolve()
    if config.tmp_root.resolve() not in path.parents or not path.is_dir():
        raise ReconcileError("manifest worktree path escapes the owned temporary root")
    git_dir = Path(
        git(
            path, "rev-parse", "--path-format=absolute", "--git-common-dir"
        ).stdout.strip()
    ).resolve()
    if git_dir != (config.tmp_root / "repository.git").resolve():
        raise ReconcileError("worktree is not owned by this command repository")
    return path


def rebase(config: Config, args: argparse.Namespace) -> dict[str, Any]:
    if not args.apply_rebase:
        raise ReconcileError("rebase is disabled without --apply-rebase")
    branch = target_branch(config, args.target)
    new_parent = validate_sha(
        args.expected_new_parent_sha or "", "--expected-new-parent-sha"
    )
    manifest = load_manifest(config)
    path = owned_worktree(config, manifest, branch)
    if git(path, "status", "--porcelain=v1", "--untracked-files=all").stdout:
        raise ReconcileError("target worktree is dirty")
    current_sha = git(path, "rev-parse", "HEAD").stdout.strip()
    recorded_sha = manifest["current_shas"].get(branch.name)
    if current_sha != recorded_sha:
        raise ReconcileError("target worktree SHA differs from the manifest")
    if current_sha != branch.old_sha:
        raise ReconcileError("target branch was already rewritten")
    if git(path, "cat-file", "-e", f"{new_parent}^{{commit}}", check=False).returncode:
        raise ReconcileError(
            "expected new parent commit is missing from the temporary repository"
        )
    old_merge_base = git(
        path, "merge-base", branch.old_parent_sha, current_sha
    ).stdout.strip()
    if old_merge_base != branch.old_parent_sha:
        raise ReconcileError("expected old parent is not the branch merge-base")

    result = git(
        path,
        "-c",
        "core.hooksPath=/dev/null",
        "rebase",
        "--committer-date-is-author-date",
        "--onto",
        new_parent,
        branch.old_parent_sha,
        branch.name,
        check=False,
    )
    if result.returncode:
        state = (
            "conflict"
            if (
                Path(
                    git(path, "rev-parse", "--git-path", "rebase-merge").stdout.strip()
                ).exists()
                or "CONFLICT" in result.stdout + result.stderr
            )
            else "failed"
        )
        raise ReconcileError(
            f"rebase stopped with state: {state}; resolve nothing automatically, then run cleanup"
        )
    rewritten_sha = git(path, "rev-parse", "HEAD").stdout.strip()
    merge_base = git(path, "merge-base", new_parent, rewritten_sha).stdout.strip()
    if merge_base != new_parent:
        raise ReconcileError(
            "rewritten branch does not have the expected new parent merge-base"
        )
    manifest["current_shas"][branch.name] = rewritten_sha
    manifest["verified"].pop(branch.name, None)
    save_manifest(config, manifest)
    return {
        "phase": "rebase",
        "schema_version": SCHEMA_VERSION,
        "branch": branch.name,
        "old_sha": branch.old_sha,
        "old_parent_sha": branch.old_parent_sha,
        "new_parent_sha": new_parent,
        "new_sha": rewritten_sha,
    }


def run_validation(command: str, path: Path) -> dict[str, Any]:
    result = run(
        ("/bin/sh", "-c", command),
        cwd=path,
        check=False,
        environment=safe_environment(),
    )
    return {
        "command_sha256": digest_text(command),
        "exit_code": result.returncode,
        "stdout_sha256": digest_text(result.stdout),
        "stderr_sha256": digest_text(result.stderr),
    }


def verify(config: Config, args: argparse.Namespace) -> dict[str, Any]:
    branch = target_branch(config, args.target)
    new_parent = validate_sha(
        args.expected_new_parent_sha or "", "--expected-new-parent-sha"
    )
    manifest = load_manifest(config)
    path = owned_worktree(config, manifest, branch)
    if git(path, "status", "--porcelain=v1", "--untracked-files=all").stdout:
        raise ReconcileError("target worktree is dirty")
    current_sha = git(path, "rev-parse", "HEAD").stdout.strip()
    if current_sha != manifest["current_shas"].get(branch.name):
        raise ReconcileError("target SHA differs from the manifest")
    merge_base = git(path, "merge-base", new_parent, current_sha).stdout.strip()
    if merge_base != new_parent:
        raise ReconcileError("target merge-base differs from the expected new parent")
    paths = changed_paths(path, new_parent, current_sha)
    unexpected = [
        item for item in paths if not path_is_allowed(item, config.allowed_paths)
    ]
    if unexpected:
        raise ReconcileError(f"unexpected changed paths: {', '.join(unexpected)}")
    if git(
        path, "diff", "--check", f"{new_parent}..{current_sha}", check=False
    ).returncode:
        raise ReconcileError("git diff --check failed")

    lockfile = run_validation(config.lockfile_command, path)
    validations = [
        run_validation(command, path) for command in config.validation_commands
    ]
    if lockfile["exit_code"] or any(item["exit_code"] for item in validations):
        raise ReconcileError(
            "a lockfile or validation command failed; output was withheld and hashed"
        )

    matches = [
        item for item in github_prs(config) if item.get("headRefName") == branch.name
    ]
    if len(matches) != 1:
        raise ReconcileError("target PR graph changed")
    pull_request = matches[0]
    remote_tip = remote_sha(
        config, branch.name, repository=config.tmp_root / "repository.git"
    )
    if pull_request.get("headRefOid") != remote_tip:
        raise ReconcileError("GitHub PR head differs from the remote branch")
    mergeability_status = "pending_push"
    if remote_tip == current_sha:
        mergeability_status = "current"
        if pull_request.get("mergeable") != "MERGEABLE":
            raise ReconcileError("current PR head is not mergeable")

    manifest["verified"][branch.name] = {
        "sha": current_sha,
        "parent_sha": new_parent,
    }
    save_manifest(config, manifest)
    return {
        "phase": "verify",
        "schema_version": SCHEMA_VERSION,
        "branch": branch.name,
        "current_sha": current_sha,
        "expected_new_parent_sha": new_parent,
        "merge_base": merge_base,
        "changed_paths": paths,
        "lockfile": lockfile,
        "validations": validations,
        "pull_request": pull_request,
        "mergeability_status": mergeability_status,
    }


def push(config: Config, args: argparse.Namespace) -> dict[str, Any]:
    if not args.apply_push:
        raise ReconcileError("push is disabled without --apply-push")
    branch = target_branch(config, args.target)
    manifest = load_manifest(config)
    path = owned_worktree(config, manifest, branch)
    if git(path, "status", "--porcelain=v1", "--untracked-files=all").stdout:
        raise ReconcileError("target worktree is dirty")
    current_sha = git(path, "rev-parse", "HEAD").stdout.strip()
    if current_sha != manifest["current_shas"].get(branch.name):
        raise ReconcileError("target SHA differs from the manifest")
    verification = manifest.get("verified", {}).get(branch.name)
    if not isinstance(verification, dict) or verification.get("sha") != current_sha:
        raise ReconcileError("target SHA has not passed the verify phase")
    observed = remote_sha(
        config, branch.name, repository=config.tmp_root / "repository.git"
    )
    if observed != branch.old_sha:
        raise ReconcileError(
            "stale lease: remote branch no longer has the exact old SHA"
        )
    repository = config.tmp_root / "repository.git"
    result = git(
        repository,
        "push",
        f"--force-with-lease=refs/heads/{branch.name}:{branch.old_sha}",
        "origin",
        f"{current_sha}:refs/heads/{branch.name}",
        check=False,
    )
    if result.returncode:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[-1]}" if detail else ""
        raise ReconcileError(f"lease-safe push failed{suffix}")
    if remote_sha(config, branch.name, repository=repository) != current_sha:
        raise ReconcileError("remote branch did not reach the expected new SHA")
    manifest["pushed_shas"][branch.name] = current_sha
    save_manifest(config, manifest)
    return {
        "phase": "push",
        "schema_version": SCHEMA_VERSION,
        "branch": branch.name,
        "lease_sha": branch.old_sha,
        "pushed_sha": current_sha,
    }


def cleanup(config: Config) -> dict[str, Any]:
    if not config.tmp_root.exists():
        return {
            "phase": "cleanup",
            "schema_version": SCHEMA_VERSION,
            "ownership_id": None,
            "removed_worktrees": [],
            "tmp_root_removed": True,
        }
    manifest = load_manifest(config)
    repository = config.tmp_root / str(manifest.get("repository", ""))
    removed: list[str] = []
    if repository.resolve().parent != config.tmp_root.resolve():
        raise ReconcileError(
            "manifest repository path escapes the owned temporary root"
        )
    for branch_name, relative in sorted(manifest.get("worktrees", {}).items()):
        path = (config.tmp_root / relative).resolve()
        if config.tmp_root.resolve() not in path.parents:
            raise ReconcileError(
                "manifest worktree path escapes the owned temporary root"
            )
        if path.exists() and repository.exists():
            git(repository, "worktree", "remove", "--force", str(path), check=False)
        if path.exists():
            shutil.rmtree(path)
        removed.append(branch_name)
    if repository.exists():
        shutil.rmtree(repository)
    ownership_id = manifest["ownership_id"]
    shutil.rmtree(config.tmp_root)
    return {
        "phase": "cleanup",
        "schema_version": SCHEMA_VERSION,
        "ownership_id": ownership_id,
        "removed_worktrees": removed,
        "tmp_root_removed": not config.tmp_root.exists(),
    }


def human_report(result: dict[str, Any]) -> str:
    phase = result["phase"]
    if phase == "inspect":
        return f"inspect: {len(result['branches'])} branch(es), exact refs, clean checkout, allowed paths"
    if phase == "prepare":
        return f"prepare: created {len(result['worktrees'])} owned worktree(s) under {result['tmp_root']}"
    if phase == "rebase":
        return f"rebase: {result['branch']} {result['old_sha'][:12]} -> {result['new_sha'][:12]}"
    if phase == "verify":
        return f"verify: {result['branch']} passed paths, merge-base, lockfile, validation, and PR checks"
    if phase == "push":
        return f"push: {result['branch']} updated with exact lease {result['lease_sha'][:12]}"
    return f"cleanup: removed {len(result['removed_worktrees'])} owned worktree(s)"


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        config = parse_config(args)
        if args.phase not in ("cleanup",):
            require_clean_stable_checkout(config)
        if args.phase == "inspect":
            result = inspect(config)
        elif args.phase == "prepare":
            result = prepare(config)
        elif args.phase == "rebase":
            result = rebase(config, args)
        elif args.phase == "verify":
            result = verify(config, args)
        elif args.phase == "push":
            result = push(config, args)
        else:
            result = cleanup(config)
        print(json.dumps(result, indent=2, sort_keys=True))
        print(human_report(result), file=sys.stderr)
        return 0
    except (ReconcileError, argparse.ArgumentTypeError) as error:
        print(
            json.dumps(
                {
                    "error": str(error),
                    "phase": args.phase,
                    "schema_version": SCHEMA_VERSION,
                },
                sort_keys=True,
            )
        )
        print(f"refused: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
