#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/tofu-plan-head.sh [options]

Run OpenTofu plan from a clean git ref in a temporary worktree (default: HEAD),
then export plan JSON for diffing against another run.

Options:
  --ref <git-ref>        Git ref to plan from (default: HEAD)
  --tf-dir <path>        Terraform/OpenTofu directory in repo (default: tf)
  --out-dir <path>       Output directory for artifacts (default: mktemp dir)
  --backend=false        Initialize without backend (local mode)
  --keep-worktree        Keep temporary worktree after completion
  -h, --help             Show this help

Artifacts:
  <out-dir>/head.plan
  <out-dir>/head.json

Example:
  scripts/tofu-plan-head.sh --ref HEAD --tf-dir tf
EOF
}

ref="HEAD"
tf_dir="tf"
out_dir=""
backend_false=0
keep_worktree=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      ref="${2:?missing value for --ref}"
      shift 2
      ;;
    --tf-dir)
      tf_dir="${2:?missing value for --tf-dir}"
      shift 2
      ;;
    --out-dir)
      out_dir="${2:?missing value for --out-dir}"
      shift 2
      ;;
    --backend=false)
      backend_false=1
      shift
      ;;
    --keep-worktree)
      keep_worktree=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel)"
if [[ -z "$out_dir" ]]; then
  out_dir="$(mktemp -d /tmp/tofu-head-plan.XXXXXX)"
else
  mkdir -p "$out_dir"
fi

worktree_dir="${out_dir}/worktree"
mkdir -p "$worktree_dir"

cleanup() {
  if [[ "$keep_worktree" -eq 0 ]] && [[ -d "$worktree_dir" ]]; then
    git -C "$repo_root" worktree remove --force "$worktree_dir" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

git -C "$repo_root" worktree add --detach "$worktree_dir" "$ref" >/dev/null

tofu_chdir="${worktree_dir}/${tf_dir}"
if [[ ! -d "$tofu_chdir" ]]; then
  echo "Directory not found in ref ${ref}: ${tf_dir}" >&2
  exit 1
fi

init_args=(init -reconfigure -input=false)
if [[ "$backend_false" -eq 1 ]]; then
  init_args=(init -backend=false -reconfigure -input=false)
fi

tofu -chdir="$tofu_chdir" "${init_args[@]}"
tofu -chdir="$tofu_chdir" plan -refresh=false -out="${out_dir}/head.plan"
tofu -chdir="$tofu_chdir" show -json "${out_dir}/head.plan" > "${out_dir}/head.json"

echo "Plan artifacts written:"
echo "  ${out_dir}/head.plan"
echo "  ${out_dir}/head.json"
if [[ "$keep_worktree" -eq 1 ]]; then
  echo "Worktree kept at: ${worktree_dir}"
fi
