# PR stack reconciliation

`pr-stack-reconcile` inspects and rewrites one pull request or an ordered stack of at most eight pull requests.

The command emits JSON on standard output. It emits one short report on standard error. Its default phases do not rewrite commits or push refs.

Run the packaged command with `nix run .#pr-stack-reconcile -- <phase> ...`.

Every phase requires these inputs:

- `--repo`: the explicit clean stable checkout.
- `--github-repo`: the explicit GitHub `OWNER/REPO` name.
- `--remote`: the explicit Git remote name.
- `--base-branch` and `--expected-base-sha`: the exact current base ref.
- one ordered `--branch NAME:OLD_SHA:OLD_PARENT_SHA` for each pull request.
- one or more repository-relative `--allowed-path` boundaries. Shell globs are allowed.
- one or more `--validation-command` values.
- one `--lockfile-command` value that checks generated lockfiles.
- `--tmp-root`: a new direct child of `/tmp`.

Do not put credentials in arguments or validation commands. The command rejects common credential forms. It withholds validation output and reports its SHA-256 digest.

Use the phases in this order:

1. Run `inspect`.
   - It checks the clean checkout, local objects, remote refs, exact SHAs, pull request graph, merge-bases, and path boundaries.
   - It does not fetch or change a ref.
2. Run `prepare` with the same arguments.
   - It creates the temporary root, ownership marker, mirror, and one worktree for each declared branch.
   - It refuses an existing temporary root.
3. Run `rebase --target NAME --expected-new-parent-sha SHA --apply-rebase` for one branch.
   - Start with the root pull request.
   - Use the emitted new SHA as the child's expected new parent.
   - The command stops on a conflict and does not edit the conflict.
4. Run `verify --target NAME --expected-new-parent-sha SHA`.
   - It checks the exact merge-base, path boundary, `git diff --check`, lockfile command, validation commands, and pull request state.
   - Before a push, it reports `pending_push` because GitHub still points to the old SHA.
5. Run `push --target NAME --apply-push` only after approval.
   - It checks the remote SHA again.
   - It uses only `--force-with-lease=refs/heads/NAME:OLD_SHA`.
   - It refuses a stale lease.
6. Run `verify` again after GitHub updates the pull request head.
   - It requires the current pull request head to be mergeable.
7. Run `cleanup`.
   - It removes only paths named by a matching ownership marker.
   - Repeated cleanup of an absent root succeeds without removing anything.

The command has no merge, pull request close, deploy, rebuild, or live branch feature. It uses `gh` only to read the remote pull request graph.
