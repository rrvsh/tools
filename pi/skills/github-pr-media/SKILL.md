---
name: github-pr-media
description: Safely adds review images to approved GitHub PRs.
compatibility: Requires pr-review-media, gh, and GitHub CLI auth.
metadata:
  author: Rafiq Rashid
---

# GitHub PR media

Use this skill only after the user approves a PR body change and media upload.
Keep route, state, viewport, and capture steps in the project workflow.

## Prepare the artifacts

1. Create an artifact directory outside every Git work tree.
2. Set the directory mode to `0700`.
3. Put only PNG, JPEG, GIF, or WebP images in the directory.
4. Set each image mode to `0600`.
5. Inspect each image for the intended content. Valid dimensions do not prove correct content.
6. Create a `0600` JSON manifest in the artifact directory.

Use this manifest form:

```json
{
  "images": [
    {"path": "desktop.png", "alt": "Desktop home page"},
    {"path": "mobile.png", "alt": "Mobile home page"}
  ]
}
```

Use direct child filenames. Do not use paths, links, or duplicate alternative text.

## Mark the PR body

Add one managed region to the PR body before the approved upload:

```markdown
<!-- pr-review-media:start -->
<!-- pr-review-media:end -->
```

The helper updates only bytes between these markers. Use `--marker-start` and `--marker-end` only for an existing custom marker pair.

## Validate first

Run the helper without `--approve-writes`:

```sh
pr-review-media \
  --repo OWNER/REPO \
  --pr NUMBER \
  --artifact-dir /absolute/path/to/artifacts \
  --manifest manifest.json
```

The default dry run validates paths, modes, manifest rows, image bytes, dimensions, image content, and official `gh` attachment support.
Set `PR_REVIEW_MEDIA_VISUAL_INSPECTOR` to an approved inspector executable when a second visual check is available.
The inspector receives JSON on standard input and must return exactly `{"ok": true}`.

## Apply an approved update

After the dry run passes, repeat the same command with `--approve-writes`.
This flag permits attachment uploads and one managed PR body update.
It does not permit commits, pushes, merges, deployments, or other PR edits.

The helper uses only an officially supported `gh pr edit --attach` flag.
It passes the PR body through standard input.
It relies on normal `gh` authentication and never requests or prints a token.
If the installed `gh` has no official attachment flag, stop at the unsupported result.
Do not use the undocumented upload endpoint, browser cookies, a release asset, a gist, or another media host.

The helper writes `.pr-review-media-upload.json` as a `0600` resume record in the artifact directory.
After a partial failure, inspect the error and repeat the exact approved command.
The helper reuses verified attachment URLs and does not insert a second body region.

## Verify

1. Confirm that the helper reports an `updated` result.
2. Confirm that each URL uses `https://github.com/user-attachments/assets/`.
3. Confirm that the anonymous check matches the repository visibility.
4. Open the PR and inspect every rendered image.
5. Run `gh pr diff NUMBER --repo OWNER/REPO --name-only`.
6. Confirm that no review media entered the source diff.
7. Keep the artifact directory private until the review ends.
