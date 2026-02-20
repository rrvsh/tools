#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 1 ]; then
  printf 'Usage: workspace <task-name> [app-dir]\n' >&2
  exit 1
fi

task_name="$1"
app_dir="${2:-$PWD}"
note_dir="${WORKSPACE_NOTE_DIR:-$HOME/0_library/notes/process}"
right_pane_percent="${WORKSPACE_RIGHT_PANE_PERCENT:-70}"

if ! command -v tmux >/dev/null 2>&1; then
  printf 'tmux is required but was not found in PATH\n' >&2
  exit 1
fi

if [ ! -d "$app_dir" ]; then
  printf 'App directory does not exist: %s\n' "$app_dir" >&2
  exit 1
fi

if ! [[ "$right_pane_percent" =~ ^[0-9]+$ ]] || [ "$right_pane_percent" -lt 1 ] || [ "$right_pane_percent" -gt 99 ]; then
  printf 'WORKSPACE_RIGHT_PANE_PERCENT must be an integer between 1 and 99\n' >&2
  exit 1
fi

slug="$(printf '%s' "$task_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
slug="${slug#-}"
slug="${slug%-}"

if [ -z "$slug" ]; then
  printf 'Task name must contain at least one alphanumeric character\n' >&2
  exit 1
fi

mkdir -p "$note_dir"

note_path="$note_dir/$(date +%F)-$slug.md"
if [ ! -e "$note_path" ]; then
  cat >"$note_path" <<EOF
# $task_name

## Goal

## Context

## Steps

## Notes

## Verification
EOF
fi

session_name="ws-$slug"

if ! tmux has-session -t "$session_name" 2>/dev/null; then
  tmux new-session -d -s "$session_name" -c "$app_dir"
  tmux send-keys -t "$session_name:0.0" "nvim \"$note_path\"" C-m
  tmux split-window -h -p "$right_pane_percent" -t "$session_name:0.0" -c "$app_dir"
  tmux select-pane -t "$session_name:0.1"
fi

if [ -n "${TMUX:-}" ]; then
  exec tmux switch-client -t "$session_name"
fi

exec tmux attach-session -t "$session_name"
