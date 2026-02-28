#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/nix-build-diff.sh [flake-attr ...]

Builds each requested flake attribute from:
1) clean HEAD (git source)
2) current working tree

Then compares both closures with nvd.

Examples:
  scripts/nix-build-diff.sh nixosConfigurations.nemesis.config.system.build.toplevel
  scripts/nix-build-diff.sh .#nixosConfigurations.nemesis.config.system.build.toplevel
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
base_ref="HEAD"

if [[ $# -eq 0 ]]; then
  set -- "nixosConfigurations.nemesis.config.system.build.toplevel"
fi

normalize_attr() {
  local attr="$1"
  attr="${attr#.}"
  attr="${attr#\#}"
  printf '%s' "$attr"
}

for raw_attr in "$@"; do
  attr="$(normalize_attr "$raw_attr")"
  working_selector=".#${attr}"
  base_selector="git+file://${repo_root}?ref=${base_ref}#${attr}"

  printf '\n==> %s\n' "$attr"
  before="$(nix build --no-link --print-out-paths "$base_selector")"
  after="$(nix build --no-link --print-out-paths "$working_selector")"

  echo "HEAD   : $before"
  echo "WORKDIR: $after"
  nix run nixpkgs#nvd -- diff "$before" "$after"
done
