#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./nix-build-diff.sh [options] [flake-attr ...]

Options:
  -b, --base REF    Compare against git REF (default: HEAD)
  -h, --help        Show this help

Builds each flake attribute from clean git REF and working tree,
then compares closures with nvd.

If no flake-attr is provided, auto-detects based on hostname and OS.

Examples:
  ./nix-build-diff.sh
  ./nix-build-diff.sh -b main
  ./nix-build-diff.sh nixosConfigurations.nemesis.config.system.build.toplevel
  ./nix-build-diff.sh -b abc123 .#nixosConfigurations.nemesis.config.system.build.toplevel
EOF
}

detect_default_attr() {
  local platform hostname
  case "$(uname -s)" in
    Linux)  platform="nixos" ;;
    Darwin) platform="darwin" ;;
    *)      echo "Error: Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
  hostname="$(hostname -s)"
  echo "${platform}Configurations.${hostname}.config.system.build.toplevel"
}

normalize_attr() {
  local attr="$1"
  attr="${attr#.}"
  attr="${attr#\#}"
  printf '%s' "$attr"
}

# Parse options that come BEFORE attributes
base_ref="HEAD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -b|--base)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --base requires an argument" >&2
        exit 1
      fi
      base_ref="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      # First non-option arg marks the start of flake attributes
      break
      ;;
  esac
done

# Use default attribute if none provided
if [[ $# -eq 0 ]]; then
  default_attr="$(detect_default_attr)"
  echo "No attribute specified, using detected: $default_attr"
  set -- "$default_attr"
fi

repo_root="$(git rev-parse --show-toplevel)"

for raw_attr in "$@"; do
  attr="$(normalize_attr "$raw_attr")"
  working_selector=".#${attr}"
  base_selector="git+file://${repo_root}?ref=${base_ref}#${attr}"

  printf '\n==> %s (comparing %s vs workdir)\n' "$attr" "$base_ref"
  before="$(nix build --no-link --print-out-paths "$base_selector")"
  after="$(nix build --no-link --print-out-paths "$working_selector")"

  echo "BASE ($base_ref): $before"
  echo "WORKDIR: $after"
  nvd -- diff "$before" "$after"
done
