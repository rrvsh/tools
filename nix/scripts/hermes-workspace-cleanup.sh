if (( $# != 2 )); then
  echo "usage: hermes-workspace-cleanup WORKSPACE SNAPSHOT_DIRECTORY" >&2
  exit 64
fi

workspace=$(readlink -e -- "$1")
snapshot=$2
if [[ ! -d "$workspace" || "$workspace" != /* || "$snapshot" != /* ]]; then
  echo "workspace and snapshot directory must be existing absolute directories" >&2
  exit 64
fi

findmnt --task 1 --json --output TARGET >"$snapshot/findmnt.json"
jq --raw-output0 -e \
  '.filesystems[] | recurse(.children[]?) | .target' \
  "$snapshot/findmnt.json" >"$snapshot/targets"
[[ -s "$snapshot/targets" ]]

find "$workspace" -xdev -type d \
  \( -name target -o -name node_modules -o -name .venv -o -name .cargo-home \) \
  -prune -print0 >"$snapshot/candidates"
while IFS= read -r -d "" path; do
  generated=""
  case "${path##*/}" in
    target)
      [[ -f "$path/CACHEDIR.TAG" || -f "$path/.rustc_info.json" ]] && generated=1
      ;;
    node_modules)
      [[ -d "$path/.bin" || -f "$path/.package-lock.json" ]] && generated=1
      ;;
    .venv)
      [[ -f "$path/pyvenv.cfg" ]] && generated=1
      ;;
    .cargo-home)
      [[ -d "$path/registry" || -d "$path/git" ]] && generated=1
      ;;
  esac
  if [[ -z "$generated" ]]; then
    echo "Skipping unrecognized build directory: $path" >&2
    continue
  fi

  has_mount=""
  while IFS= read -r -d "" mount; do
    if
      [[ "$mount" == "$path" || "$mount" == "$path/"* ]] \
        || [[ "$mount" != "/" && "$path" == "$mount/"* ]]
    then
      has_mount=1
      break
    fi
  done <"$snapshot/targets"
  if [[ -n "$has_mount" ]]; then
    echo "Skipping build directory with a mount: $path" >&2
    continue
  fi

  find "$path" -xdev -mmin -60 -print0 -quit >"$snapshot/recent"
  if [[ -s "$snapshot/recent" ]]; then
    echo "Skipping recently active build directory: $path" >&2
    continue
  fi

  referenced=""
  for reference in \
    /proc/[0-9]*/cwd \
    /proc/[0-9]*/root \
    /proc/[0-9]*/exe \
    /proc/[0-9]*/fd/* \
    /proc/[0-9]*/map_files/*
  do
    resolved=$(readlink -f -- "$reference" 2>/dev/null) || continue
    if [[ "$resolved" == "$path" || "$resolved" == "$path/"* ]]; then
      referenced=1
      break
    fi
  done
  if [[ -n "$referenced" ]]; then
    echo "Skipping process-referenced build directory: $path" >&2
    continue
  fi

  rm -rf --one-file-system -- "$path"
done <"$snapshot/candidates"
