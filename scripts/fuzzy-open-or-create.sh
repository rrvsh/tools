#!/usr/bin/env bash

set -euo pipefail

dir="${1:-$HOME/0_library/notes/process}"
editor="${EDITOR:-nvim}"

mkdir -p "$dir"

mapfile -t out < <(
  {
    find "$dir" -type f 2>/dev/null
    rg --line-number --no-heading --color=never "." "$dir" 2>/dev/null || true
  } | sk --print-query --bind "enter:accept,alt-enter:accept(__CREATE_MD__)"
)

if [ "${#out[@]}" -lt 2 ]; then
  exit 0
fi

query="${out[0]}"
choice="${out[1]}"

if [ "$choice" = "__CREATE_MD__" ]; then
  if [ -z "$query" ]; then
    exit 0
  fi

  choice="$dir/$query.md"
  mkdir -p "$(dirname "$choice")"
  if [ ! -e "$choice" ]; then
    touch "$choice"
  fi
fi

if [ -f "$choice" ]; then
  exec "$editor" "$choice"
fi

if [[ "$choice" =~ ^(.+):([0-9]+): ]]; then
  path="${BASH_REMATCH[1]}"
  line="${BASH_REMATCH[2]}"
  if [ -f "$path" ]; then
    exec "$editor" "+${line}" "$path"
  fi
fi

exec "$editor" "$choice"
