#!/usr/bin/env bash
set -euo pipefail

: "${HERMES_BIN:?HERMES_BIN must be set}"
: "${HERMES_HOME:?HERMES_HOME must be set}"
: "${HERMES_JOB_PROMPT:?HERMES_JOB_PROMPT must be set}"
: "${HERMES_JOB_NAME:?HERMES_JOB_NAME must be set}"
: "${HERMES_JOB_DELIVERY:?HERMES_JOB_DELIVERY must be set}"

jobs="$HERMES_HOME/cron/jobs.json"
manifest="$HERMES_HOME/cron/nix-active-worker-heartbeat-job-id"
prompt="$(<"$HERMES_JOB_PROMPT")"

install -d -m 0770 "$HERMES_HOME/active-workers"
install -d -m 0770 "$HERMES_HOME/cron"

declared_id=""
if [ -f "$manifest" ]; then
  declared_id="$(tr -d '[:space:]' <"$manifest")"
  if ! [[ "$declared_id" =~ ^[a-f0-9]{12}$ ]]; then
    echo "Invalid managed Hermes cron job ID in $manifest" >&2
    exit 1
  fi
fi

if [ -f "$jobs" ]; then
  jq -e '
    def jobs:
      if type == "object" then
        if (.jobs | type) == "array" then .jobs
        else error("invalid Hermes cron job store")
        end
      else error("invalid Hermes cron job store")
      end;
    jobs | all(.[]; type == "object" and (.id | type == "string") and (.name | type == "string"))
  ' "$jobs" >/dev/null
fi

matches=()
if [ -f "$jobs" ]; then
  match_output="$(
    jq -r --arg name "$HERMES_JOB_NAME" \
      '.jobs[] | select(.name == $name) | .id' \
      "$jobs"
  )"
  if [ -n "$match_output" ]; then
    mapfile -t matches <<<"$match_output"
  fi
fi
if [ "${#matches[@]}" -gt 1 ]; then
  echo "More than one Hermes cron job is named '$HERMES_JOB_NAME'; refusing to choose one." >&2
  printf '  %s\n' "${matches[@]}" >&2
  exit 1
fi

job_id=""
if [ -f "$jobs" ] && [ -n "$declared_id" ]; then
  declared_name="$(
    jq -r --arg id "$declared_id" \
      '.jobs[] | select(.id == $id) | .name // ""' \
      "$jobs"
  )"
  if [ -n "$declared_name" ] && [ "$declared_name" != "$HERMES_JOB_NAME" ]; then
    echo "Managed Hermes cron job $declared_id is now named '$declared_name'; refusing to edit it." >&2
    exit 1
  fi
  if [ "$declared_name" = "$HERMES_JOB_NAME" ]; then
    job_id="$declared_id"
  fi
fi

if [ -z "$job_id" ]; then
  if [ "${#matches[@]}" -eq 1 ]; then
    job_id="${matches[0]}"
  else
    create_output="$($HERMES_BIN cron create "every 10m" "$prompt" \
      --name "$HERMES_JOB_NAME" \
      --deliver "$HERMES_JOB_DELIVERY" \
      --repeat 0 \
      --script active-worker-supervisor.py \
      --model deepseek/deepseek-v4-flash-0731 \
      --provider openrouter \
      --continuity)"
    printf '%s\n' "$create_output"
    job_id="$(printf '%s\n' "$create_output" | awk '/^Created job:/ { print $3 }')"
    if ! [[ "$job_id" =~ ^[a-f0-9]{12}$ ]]; then
      echo "Hermes created the job but did not return a valid job ID." >&2
      exit 1
    fi
  fi

  temporary="$(mktemp "$manifest.XXXXXX")"
  printf '%s\n' "$job_id" >"$temporary"
  chmod 0600 "$temporary"
  mv "$temporary" "$manifest"
fi

$HERMES_BIN cron edit "$job_id" \
  --name "$HERMES_JOB_NAME" \
  --schedule "every 10m" \
  --prompt "$prompt" \
  --deliver "$HERMES_JOB_DELIVERY" \
  --repeat 0 \
  --script active-worker-supervisor.py \
  --agent \
  --clear-skills \
  --continuity \
  --monitor-script "" \
  --monitor-url "" \
  --workdir "" \
  --model deepseek/deepseek-v4-flash-0731 \
  --provider openrouter
$HERMES_BIN cron resume "$job_id"
