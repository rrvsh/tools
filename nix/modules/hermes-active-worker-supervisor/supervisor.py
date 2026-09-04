#!/usr/bin/env python3
"""Gate the Hermes active-worker supervisor on stable worker state."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import shlex
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

DEFAULT_HERMES_HOME = Path("/var/lib/hermes/.hermes")
HERMES_HOME = Path(os.environ.get("HERMES_HOME", DEFAULT_HERMES_HOME))
REGISTRY_DIR = Path(
    os.environ.get("HERMES_ACTIVE_WORKER_DIR", HERMES_HOME / "active-workers")
)
STATE_PATH = Path(
    os.environ.get(
        "HERMES_ACTIVE_WORKER_STATE",
        HERMES_HOME / "cron" / "active-worker-supervisor-state.json",
    )
)
STALL_AFTER_SECONDS = int(os.environ.get("HERMES_ACTIVE_WORKER_STALL_SECONDS", "1200"))
COMMAND_TIMEOUT_SECONDS = 30
VALID_ID = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
VALID_HOST = re.compile(r"^[A-Za-z0-9_.@-]+$")
VALID_UNIT = re.compile(r"^[A-Za-z0-9_.@:-]+\.service$")
VALID_REPOSITORY = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
VALID_STATUSES = {"active", "completed", "cancelled"}

REMOTE_PROBE = r"""
set -u
unit=$1
checkout=$2
result_file=$3

command -v systemctl >/dev/null 2>&1 || exit 20
systemctl --user show-environment >/dev/null 2>&1 || exit 21

load=$(systemctl --user show "$unit" -p LoadState --value 2>/dev/null || true)
active=$(systemctl --user show "$unit" -p ActiveState --value 2>/dev/null || true)
sub=$(systemctl --user show "$unit" -p SubState --value 2>/dev/null || true)
result=$(systemctl --user show "$unit" -p Result --value 2>/dev/null || true)
exec_status=$(systemctl --user show "$unit" -p ExecMainStatus --value 2>/dev/null || true)
cgroup=$(systemctl --user show "$unit" -p ControlGroup --value 2>/dev/null || true)
printf 'UNIT\t%s\t%s\t%s\t%s\t%s\n' "$load" "$active" "$sub" "$result" "$exec_status"

if [ -n "$cgroup" ] && [ -r "/sys/fs/cgroup$cgroup/cgroup.procs" ]; then
  while IFS= read -r process_id; do
    executable=$(readlink "/proc/$process_id/exe" 2>/dev/null || true)
    [ -n "$executable" ] && printf 'PROCESS\t%s\n' "${executable##*/}"
  done <"/sys/fs/cgroup$cgroup/cgroup.procs"
fi

if git -C "$checkout" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  head=$(git -C "$checkout" rev-parse HEAD 2>/dev/null || true)
  branch=$(git -C "$checkout" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  worktree_hash=$(
    {
      git -C "$checkout" diff --binary HEAD 2>/dev/null || true
      git -C "$checkout" ls-files --others --exclude-standard -z 2>/dev/null |
        while IFS= read -r -d '' path; do
          printf '%s\0' "$path"
          sha256sum "$checkout/$path" 2>/dev/null || true
        done
    } | sha256sum | cut -d' ' -f1
  )
  printf 'REPO\t%s\t%s\t%s\n' "$head" "$branch" "$worktree_hash"
else
  printf 'REPO\tmissing\t\t\n'
fi

if [ -n "$result_file" ] && [ -f "$result_file" ]; then
  result_hash=$(sha256sum "$result_file" | cut -d' ' -f1)
  printf 'RESULT\tpresent\t%s\n' "$result_hash"
elif [ -n "$result_file" ]; then
  printf 'RESULT\tmissing\t\n'
else
  printf 'RESULT\tunconfigured\t\n'
fi
"""


def run(command: list[str], timeout: int = COMMAND_TIMEOUT_SECONDS) -> dict[str, Any]:
    """Run a probe and return stable output or a stable failure class."""
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return {"status": "timeout"}
    except OSError:
        return {"status": "unavailable"}

    if result.returncode != 0:
        return {"status": "failed", "exit": result.returncode}
    return {"status": "ok", "stdout": result.stdout}


def validate_metadata(raw: Any, source: Path) -> dict[str, Any]:
    """Validate and normalize one worker registration."""
    if not isinstance(raw, dict):
        raise ValueError(f"{source}: registration must be a JSON object")

    required = {"id", "status", "host", "unit", "checkout"}
    missing = sorted(required - raw.keys())
    if missing:
        raise ValueError(f"{source}: missing fields: {', '.join(missing)}")

    metadata = {key: raw.get(key) for key in required}
    metadata.update(
        {
            "repository": raw.get("repository"),
            "pr": raw.get("pr"),
            "result_file": raw.get("result_file"),
        }
    )
    if not isinstance(metadata["id"], str) or not VALID_ID.fullmatch(metadata["id"]):
        raise ValueError(f"{source}: invalid id")
    if source.stem != metadata["id"]:
        raise ValueError(f"{source}: filename must match id")
    if metadata["status"] not in VALID_STATUSES:
        raise ValueError(f"{source}: invalid status")
    if not isinstance(metadata["host"], str) or not VALID_HOST.fullmatch(
        metadata["host"]
    ):
        raise ValueError(f"{source}: invalid host")
    if not isinstance(metadata["unit"], str) or not VALID_UNIT.fullmatch(
        metadata["unit"]
    ):
        raise ValueError(f"{source}: invalid unit")
    for field in ("checkout", "result_file"):
        value = metadata[field]
        if value is not None and (
            not isinstance(value, str) or not value.startswith("/")
        ):
            raise ValueError(f"{source}: {field} must be an absolute path")
    repository = metadata["repository"]
    pr = metadata["pr"]
    if (repository is None) != (pr is None):
        raise ValueError(f"{source}: repository and pr must be set together")
    if repository is not None and (
        not isinstance(repository, str) or not VALID_REPOSITORY.fullmatch(repository)
    ):
        raise ValueError(f"{source}: invalid repository")
    if pr is not None and (not isinstance(pr, int) or isinstance(pr, bool) or pr <= 0):
        raise ValueError(f"{source}: pr must be a positive integer")
    return dict(sorted(metadata.items()))


def load_registry() -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    """Load valid worker records and stable registration errors."""
    workers: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    if not REGISTRY_DIR.exists():
        return workers, errors

    for source in sorted(REGISTRY_DIR.glob("*.json")):
        try:
            workers.append(validate_metadata(json.loads(source.read_text()), source))
        except (OSError, json.JSONDecodeError, ValueError) as error:
            errors.append({"file": source.name, "error": str(error)})
    return workers, errors


def parse_remote_probe(result: dict[str, Any]) -> dict[str, Any]:
    """Convert remote line output into a stable worker snapshot."""
    if result.get("status") != "ok":
        return result

    snapshot: dict[str, Any] = {"status": "ok", "processes": []}
    for line in str(result.get("stdout", "")).splitlines():
        fields = line.split("\t")
        if fields[0] == "UNIT" and len(fields) == 6:
            snapshot["unit"] = {
                "load": fields[1],
                "active": fields[2],
                "sub": fields[3],
                "result": fields[4],
                "exit_status": fields[5],
            }
        elif fields[0] == "PROCESS" and len(fields) == 2:
            snapshot["processes"].append(fields[1])
        elif fields[0] == "REPO" and len(fields) == 4:
            snapshot["checkout"] = {
                "head": fields[1],
                "branch": fields[2],
                "worktree_hash": fields[3],
            }
        elif fields[0] == "RESULT" and len(fields) == 3:
            snapshot["result_file"] = {"state": fields[1], "sha256": fields[2]}
    snapshot["processes"] = sorted(set(snapshot["processes"]))
    return snapshot


def probe_worker(metadata: dict[str, Any]) -> dict[str, Any]:
    """Probe the registered unit, checkout, result file, and optional PR."""
    remote_command = " ".join(
        [
            "bash",
            "-lc",
            shlex.quote(REMOTE_PROBE),
            "--",
            shlex.quote(metadata["unit"]),
            shlex.quote(metadata["checkout"]),
            shlex.quote(metadata.get("result_file") or ""),
        ]
    )
    host = metadata["host"]
    command = (
        ["bash", "-lc", remote_command]
        if host in {"localhost", "local"}
        else [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            host,
            remote_command,
        ]
    )
    snapshot = {
        "metadata": metadata,
        "worker": parse_remote_probe(run(command)),
    }
    if metadata.get("repository") and metadata.get("pr"):
        snapshot["pull_request"] = probe_pull_request(
            metadata["repository"], metadata["pr"]
        )
    return snapshot


def normalize_checks(raw_checks: Any) -> list[dict[str, str]]:
    """Keep only stable check identity and state fields from GitHub."""
    checks: list[dict[str, str]] = []
    if not isinstance(raw_checks, list):
        return checks
    for raw in raw_checks:
        if not isinstance(raw, dict):
            continue
        name = raw.get("name") or raw.get("context") or "unknown"
        status = raw.get("status") or raw.get("state") or ""
        conclusion = raw.get("conclusion") or ""
        checks.append(
            {
                "name": str(name),
                "status": str(status),
                "conclusion": str(conclusion),
            }
        )
    return sorted(checks, key=lambda check: tuple(check.values()))


def probe_pull_request(repository: str, number: int) -> dict[str, Any]:
    """Read stable PR head and check state through the GitHub CLI."""
    result = run(
        [
            "gh",
            "pr",
            "view",
            str(number),
            "--repo",
            repository,
            "--json",
            "headRefOid,state,isDraft,mergeStateStatus,statusCheckRollup",
        ]
    )
    if result.get("status") != "ok":
        return result
    try:
        raw = json.loads(result.get("stdout", ""))
    except json.JSONDecodeError:
        return {"status": "invalid-response"}
    return {
        "status": "ok",
        "head": raw.get("headRefOid"),
        "state": raw.get("state"),
        "draft": raw.get("isDraft"),
        "merge_state": raw.get("mergeStateStatus"),
        "checks": normalize_checks(raw.get("statusCheckRollup")),
    }


def stable_signature(snapshot: dict[str, Any]) -> str:
    """Hash only the explicit stable snapshot."""
    canonical = json.dumps(snapshot, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()


def read_state() -> dict[str, Any]:
    try:
        state = json.loads(STATE_PATH.read_text())
        return state if isinstance(state, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def write_state(state: dict[str, Any]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", dir=STATE_PATH.parent, prefix=f".{STATE_PATH.name}.", delete=False
    ) as temporary:
        temporary.write(json.dumps(state, indent=2, sort_keys=True) + "\n")
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, STATE_PATH)


def task_is_running(task: dict[str, Any]) -> bool:
    """Return true when an active registration has a running unit and process."""
    if task.get("metadata", {}).get("status") != "active":
        return False
    worker = task.get("worker", {})
    return worker.get("unit", {}).get("active") == "active" and bool(
        worker.get("processes")
    )


def baseline_requires_attention(snapshot: dict[str, Any]) -> bool:
    """Wake for an unhealthy initial state while keeping healthy baselines silent."""
    if snapshot.get("registration_errors"):
        return True
    for task in snapshot.get("tasks", []):
        if task.get("metadata", {}).get("status") != "active":
            continue
        worker = task.get("worker", {})
        unit = worker.get("unit", {})
        if (
            worker.get("status") != "ok"
            or unit.get("active") != "active"
            or not worker.get("processes")
        ):
            return True
        checkout = worker.get("checkout", {})
        if not isinstance(checkout, dict) or checkout.get("head") in {
            None,
            "",
            "missing",
        }:
            return True
        pull_request = task.get("pull_request")
        if pull_request is not None and pull_request.get("status") != "ok":
            return True
    return False


def state_time(value: Any, fallback: int) -> int:
    """Return a valid stored epoch value or a safe fallback."""
    return value if isinstance(value, int) and not isinstance(value, bool) else fallback


def decide_wake(
    snapshot: dict[str, Any], previous: dict[str, Any], now: int
) -> tuple[bool, str, dict[str, Any]]:
    """Apply baseline, state-change, and per-worker one-shot stall wake rules."""
    signature = stable_signature(snapshot)
    previous_signature = previous.get("signature")
    baseline = not isinstance(previous_signature, str)
    changed = not baseline and signature != previous_signature
    previous_tasks = previous.get("tasks")
    if not isinstance(previous_tasks, dict):
        previous_tasks = {}

    task_states: dict[str, dict[str, Any]] = {}
    stalled_tasks: list[str] = []
    for task in snapshot.get("tasks", []):
        worker_id = task.get("metadata", {}).get("id")
        if not isinstance(worker_id, str):
            continue
        task_signature = stable_signature(task)
        old_task = previous_tasks.get(worker_id)
        if not isinstance(old_task, dict):
            old_task = {}
        old_signature = old_task.get("signature")
        task_baseline = not isinstance(old_signature, str)
        task_changed = not task_baseline and task_signature != old_signature
        last_change_at = (
            now
            if task_baseline or task_changed
            else state_time(old_task.get("last_change_at"), now)
        )
        stalled = (
            not task_baseline
            and not task_changed
            and task_is_running(task)
            and now - last_change_at >= STALL_AFTER_SECONDS
            and old_task.get("stall_alert_signature") != task_signature
        )
        if stalled:
            stalled_tasks.append(worker_id)
            stall_alert_signature = task_signature
        elif task_changed:
            stall_alert_signature = None
        else:
            stall_alert_signature = old_task.get("stall_alert_signature")
        task_states[worker_id] = {
            "signature": task_signature,
            "last_change_at": last_change_at,
            "stall_alert_signature": stall_alert_signature,
        }

    initial_problem = baseline and baseline_requires_attention(snapshot)
    if initial_problem:
        reason = "baseline_requires_attention"
    elif baseline:
        reason = "baseline"
    elif stalled_tasks:
        reason = "possible_stall"
    elif changed:
        reason = "state_changed"
    else:
        reason = "unchanged"

    next_state = {
        "signature": signature,
        "tasks": task_states,
        "stalled_tasks": stalled_tasks,
        "observed_at": now,
        "snapshot": snapshot,
    }
    return initial_problem or changed or bool(stalled_tasks), reason, next_state


def main() -> int:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    lock_path = STATE_PATH.with_suffix(f"{STATE_PATH.suffix}.lock")
    with lock_path.open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        workers, errors = load_registry()
        snapshot = {
            "registration_errors": errors,
            "tasks": [probe_worker(worker) for worker in workers],
        }
        wake, reason, state = decide_wake(snapshot, read_state(), int(time.time()))
        write_state(state)
    if wake:
        print(
            json.dumps(
                {
                    "reason": reason,
                    "stalled_tasks": state.get("stalled_tasks", []),
                    "snapshot": snapshot,
                },
                sort_keys=True,
            )
        )
        print('{"wakeAgent": true}')
    else:
        print('{"wakeAgent": false}')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
