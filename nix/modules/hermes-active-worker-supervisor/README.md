# Hermes active-worker supervisor

Mercury runs one managed Hermes cron job named `active-worker-heartbeat`. The job runs every ten minutes. Its pre-check script wakes the agent only after stable task state changes or one active state remains unchanged for 20 minutes.

The NixOS module owns only this named job. It records the random Hermes job ID in:

```text
/var/lib/hermes/.hermes/cron/nix-active-worker-heartbeat-job-id
```

Reconciliation edits that ID through `hermes cron`. If the manifest is missing, it adopts one exact name match. It stops on duplicate names, invalid job data, or an ID that now names another job. It never replaces `jobs.json` or removes another job. Hermes cannot start when this reconciliation fails.

The job delivers to Rafiq's explicit Telegram chat. It also keeps cron continuity and the existing `active-worker-heartbeat-state.md` ledger to prevent duplicate reports.

## Register a worker

Run `hermes-worker` on Mercury before starting a durable worker:

```sh
hermes-worker register project-pr-123 \
  --host nemesis \
  --unit project-pr123-worker.service \
  --checkout /tmp/project-pr123-worker \
  --repository owner/project \
  --pr 123 \
  --result-file /tmp/project-pr123-worker-result.txt
```

The ID is a stable local name. The unit must be a systemd user service. The checkout and result file paths are paths on the named host. Set `--repository` and `--pr` together when the task has a pull request.

Registration is idempotent when the metadata is unchanged. Use `--replace` only when an active task moves to a different unit, checkout, result file, host, or pull request.

The module does not import the old hard-coded task list. After the first activation, register each worker that is still active. This keeps the migration state outside the repository.

Registrations are mutable runtime state under:

```text
/var/lib/hermes/.hermes/active-workers/
```

Do not add a current task or pull request to the Nix module.

## Represent task lifecycle

Use these commands on Mercury:

```sh
hermes-worker completed project-pr-123
hermes-worker cancelled project-pr-123
hermes-worker active project-pr-123
hermes-worker remove project-pr-123
hermes-worker list
```

- `active` means the supervisor must probe the task and apply stall detection.
- `completed` means the worker owner believes the task ended. The Hermes agent still requires direct proof before it reports completion.
- `cancelled` records an intentional stop. Cancellation alone does not produce a Telegram message.
- `remove` stops all future probes for that task. Remove a record after its final state has been observed.

A worker prompt remains the authority for allowed actions. Registration does not grant permission to merge, deploy, restart, or discard work.

## Stable state rules

The pre-check signature contains:

- registration metadata and lifecycle state
- unit load, active, substate, result, and exit state
- process executable names from the unit cgroup
- checkout head, branch, and content hash
- result-file presence and content hash
- pull request head, state, merge state, and check states

The signature excludes timestamps, elapsed time, process arguments, all process IDs, and the probe process. Stall timers are kept per worker, so progress in one task cannot hide a stalled task. The state file stores observation time only to enforce the stall threshold. Healthy initial baselines and unchanged states return `{"wakeAgent": false}`. Agent output containing `[SILENT]` is the fallback for ordinary progress after a real state change wakes the agent.
