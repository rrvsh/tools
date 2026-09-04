#!/usr/bin/env python3
"""Manage durable task metadata for the Hermes active-worker supervisor."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any

DEFAULT_HERMES_HOME = Path("/var/lib/hermes/.hermes")
HERMES_HOME = Path(os.environ.get("HERMES_HOME", DEFAULT_HERMES_HOME))
REGISTRY_DIR = Path(
    os.environ.get("HERMES_ACTIVE_WORKER_DIR", HERMES_HOME / "active-workers")
)
VALID_ID = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
VALID_HOST = re.compile(r"^[A-Za-z0-9_.@-]+$")
VALID_UNIT = re.compile(r"^[A-Za-z0-9_.@:-]+\.service$")
VALID_REPOSITORY = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
VALID_STATUSES = {"active", "completed", "cancelled"}


def worker_path(worker_id: str) -> Path:
    if not VALID_ID.fullmatch(worker_id):
        raise ValueError("worker id must match [a-z0-9][a-z0-9._-]*")
    return REGISTRY_DIR / f"{worker_id}.json"


def validate_worker(worker: Any, expected_id: str) -> dict[str, Any]:
    if not isinstance(worker, dict):
        raise ValueError(f"worker registration is invalid: {expected_id}")
    required = {"id", "status", "host", "unit", "checkout"}
    missing = sorted(required - worker.keys())
    if missing:
        raise ValueError(f"worker registration is missing: {', '.join(missing)}")
    if worker.get("id") != expected_id:
        raise ValueError(
            f"worker registration id does not match its filename: {expected_id}"
        )
    if worker.get("status") not in VALID_STATUSES:
        raise ValueError("worker status is invalid")
    host = worker.get("host")
    if not isinstance(host, str) or not VALID_HOST.fullmatch(host):
        raise ValueError("host contains unsupported characters")
    unit = worker.get("unit")
    if not isinstance(unit, str) or not VALID_UNIT.fullmatch(unit):
        raise ValueError("unit must be a systemd .service name")
    checkout = worker.get("checkout")
    if not isinstance(checkout, str) or not checkout.startswith("/"):
        raise ValueError("checkout must be an absolute path")
    result_file = worker.get("result_file")
    if result_file is not None and (
        not isinstance(result_file, str) or not result_file.startswith("/")
    ):
        raise ValueError("result file must be an absolute path")
    repository = worker.get("repository")
    pull_request = worker.get("pr")
    if (repository is None) != (pull_request is None):
        raise ValueError("repository and PR must be set together")
    if repository is not None and (
        not isinstance(repository, str) or not VALID_REPOSITORY.fullmatch(repository)
    ):
        raise ValueError("repository must use owner/name form")
    if pull_request is not None and (
        not isinstance(pull_request, int)
        or isinstance(pull_request, bool)
        or pull_request <= 0
    ):
        raise ValueError("PR must be a positive integer")
    return worker


def read_worker(worker_id: str) -> dict[str, Any]:
    path = worker_path(worker_id)
    try:
        worker = json.loads(path.read_text())
    except FileNotFoundError as error:
        raise ValueError(f"worker is not registered: {worker_id}") from error
    except json.JSONDecodeError as error:
        raise ValueError(f"worker registration is invalid: {worker_id}") from error
    return validate_worker(worker, worker_id)


def write_worker(worker: dict[str, Any]) -> None:
    worker_id = str(worker.get("id", ""))
    validate_worker(worker, worker_id)
    REGISTRY_DIR.mkdir(parents=True, exist_ok=True)
    path = worker_path(worker_id)
    with tempfile.NamedTemporaryFile(
        "w", dir=REGISTRY_DIR, prefix=f".{worker_id}.", delete=False
    ) as temporary:
        temporary.write(json.dumps(worker, indent=2, sort_keys=True) + "\n")
        temporary_path = Path(temporary.name)
    os.chmod(temporary_path, 0o660)
    os.replace(temporary_path, path)


def registration_from_args(args: argparse.Namespace) -> dict[str, Any]:
    return validate_worker(
        {
            "id": args.worker_id,
            "status": "active",
            "host": args.host,
            "unit": args.unit,
            "checkout": args.checkout,
            "repository": args.repository,
            "pr": args.pr,
            "result_file": args.result_file,
        },
        args.worker_id,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage metadata for the Hermes active-worker supervisor."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    register = subparsers.add_parser("register", help="register an active worker")
    register.add_argument("worker_id")
    register.add_argument("--host", required=True)
    register.add_argument("--unit", required=True)
    register.add_argument("--checkout", required=True)
    register.add_argument("--repository")
    register.add_argument("--pr", type=int)
    register.add_argument("--result-file")
    register.add_argument(
        "--replace", action="store_true", help="replace different existing metadata"
    )

    for command in sorted(VALID_STATUSES):
        status_parser = subparsers.add_parser(command, help=f"mark a worker {command}")
        status_parser.add_argument("worker_id")

    remove = subparsers.add_parser("remove", help="remove a worker registration")
    remove.add_argument("worker_id")

    subparsers.add_parser("list", help="list worker registrations")
    return parser


def execute(args: argparse.Namespace) -> int:
    if args.command == "register":
        worker = registration_from_args(args)
        path = worker_path(args.worker_id)
        if path.exists():
            existing = read_worker(args.worker_id)
            if existing == worker:
                print(f"Worker already registered: {args.worker_id}")
                return 0
            if not args.replace:
                raise ValueError(
                    f"worker already has different metadata: {args.worker_id}; use --replace"
                )
        write_worker(worker)
        print(f"Registered worker: {args.worker_id}")
        return 0

    if args.command in VALID_STATUSES:
        worker = read_worker(args.worker_id)
        worker["status"] = args.command
        write_worker(worker)
        print(f"Marked worker {args.command}: {args.worker_id}")
        return 0

    if args.command == "remove":
        path = worker_path(args.worker_id)
        if path.exists():
            read_worker(args.worker_id)
            path.unlink()
        print(f"Removed worker registration: {args.worker_id}")
        return 0

    registrations = []
    if REGISTRY_DIR.exists():
        for path in sorted(REGISTRY_DIR.glob("*.json")):
            try:
                registrations.append(read_worker(path.stem))
            except (OSError, ValueError):
                registrations.append({"id": path.stem, "status": "invalid"})
    print(json.dumps(registrations, indent=2, sort_keys=True))
    return 0


def main() -> int:
    args = build_parser().parse_args()
    try:
        REGISTRY_DIR.mkdir(parents=True, exist_ok=True)
        with (REGISTRY_DIR / ".registry.lock").open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            return execute(args)
    except (OSError, ValueError) as error:
        print(f"hermes-worker: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
