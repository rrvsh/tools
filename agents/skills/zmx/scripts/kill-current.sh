#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == "--finish" ]]; then
    session=$2
    containing_shell=$3
    zmx=$4

    sleep 1
    "$zmx" kill "$session" --force
    kill -TERM "$containing_shell"
    exit
fi

session=${ZMX_SESSION:-}

if [[ -z $session ]]; then
    echo "Not inside a ZMX session." >&2
    exit 1
fi

pid=$$
containing_shell=

while [[ $pid =~ ^[0-9]+$ ]] && ((pid > 1)); do
    command_line=$(ps -p "$pid" -o command=)
    parent=$(ps -p "$pid" -o ppid= | xargs)

    if [[ $command_line == *"zmx attach $session"* ]]; then
        containing_shell=$parent
    fi

    pid=$parent
done

if [[ -z $containing_shell ]]; then
    echo "Could not identify the containing shell." >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
script="$script_dir/$(basename -- "$0")"
zmx=$(command -v zmx)

nohup "$script" \
    --finish "$session" "$containing_shell" "$zmx" \
    >"/tmp/zmx-murder-$session.log" 2>&1 </dev/null &
