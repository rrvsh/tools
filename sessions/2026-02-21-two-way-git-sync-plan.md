## Task

Provide a practical plan for two-way Git sync where two non-bare repositories can push and pull directly from each other.

## Retrieval-led notes

- Reviewed `.agents/skills/web-search/SKILL.md` and used `ddgr` web search for relevant Git docs.
- Verified behavior in `git-config` docs for `receive.denyCurrentBranch=updateInstead` and clean worktree requirement.
- Reviewed `githooks` docs for `push-to-checkout` hook behavior with `updateInstead`.

## Decisions

- Recommend using `receive.denyCurrentBranch=updateInstead` on both devices.
- Recommend branch protection settings that reduce accidental history rewrites (`receive.denyNonFastForwards=true`, `receive.denyDeletes=true`).
- Recommend a symmetric workflow: commit -> pull --rebase from peer -> push to peer.

## Risks and mitigations

- Push to checked-out branch fails if remote worktree is dirty under `updateInstead`.
  - Mitigation: keep both repos clean before sync, or use a dedicated sync branch.
- Concurrent independent commits can diverge.
  - Mitigation: always pull/rebase before push and resolve conflicts locally.

## Outcome

- Prepared concise setup + operating plan and troubleshooting checklist for user.

## Follow-up implementation

### Goal

Implement a Rust crate/service that watches a repo, auto-commits changes, syncs to peers, and writes `MERGE_CONFLICT` with diff summary on rebase conflicts.

### Work breakdown

- Added new workspace crate: `rs/git-peer-sync`.
- Implemented sync engine in `rs/git-peer-sync/src/lib.rs`:
  - `sync_once` to stage/commit and sync peers.
  - `watch_and_sync` with `notify` recursive watcher and debounce.
  - Peer sync via `git pull --rebase` then `git push`.
  - Conflict detection (`git ls-files -u`) and `MERGE_CONFLICT` writing.
  - Rebase abort after conflict summary capture.
- Implemented CLI in `rs/git-peer-sync/src/main.rs`:
  - `watch` and `sync-once` commands.
  - Supports both `--hosts` (ssh hostnames, same repo path) and `--peer-url NAME=URL` overrides.
- Added workspace member in `rs/Cargo.toml`.
- Updated Nix packages output in `nix/outputs/packages.nix`:
  - Added `packages.git-peer-sync` via `buildRustPackage`.
  - Added runtime wrapper PATH for `git` and `openssh`.
  - Added `nativeCheckInputs = [ pkgs.git ]` so tests can execute git in sandbox.

### Bugs encountered and fixes

- **Watcher path type mismatch (`&PathBuf` vs `&Path`)**
  - Fixed by using closure adapter in `.any(|path| is_git_internal_path(path))`.
- **First push to empty peer branch failed (`couldn't find remote ref main`)**
  - Added explicit detection for missing-remote-branch pull error and allowed initial push to continue.
- **Nix package build failed: crate path missing in source**
  - Root cause: untracked files are excluded from flake source snapshots.
  - Fixed by staging new crate files before Nix build test.
- **Nix package check failed: tests couldn't find `git` in sandbox**
  - Fixed by adding `nativeCheckInputs = [ pkgs.git ]`.
- **Strict clippy failures from repository lint policy**
  - Added missing crate metadata, docs for `Result` APIs, `#[must_use]` where required, and formatted error strings.
  - Added `#![allow(clippy::multiple_crate_versions)]` to handle unavoidable transitive version duplication.

### Validation performed

- `cargo test --manifest-path rs/Cargo.toml -p git-peer-sync` passed.
- `cargo clippy --manifest-path rs/Cargo.toml -p git-peer-sync --all-targets` passed.
- `nix build .#git-peer-sync` passed after packaging fixes.
- Manual runtime verification with temporary repos:
  - Success path: `sync-once` auto-commit + push updates peer non-bare repo.
  - Conflict path: `sync-once` exits non-zero and creates `MERGE_CONFLICT` containing peer, file list, status, and conflict diff.
