# 2026-02-28 - flake input dedupe

## Task
- Use Flint duplicate report to deduplicate `flake.nix` inputs and validate evaluation timing before and after.

## Work breakdown
1. Ran baseline eval timing with `nix flake check --no-build`.
2. Updated `flake.nix` inputs to add/expand `follows` wiring for duplicated `nixpkgs` and `rust-overlay` trees.
3. Re-ran `nix flake check --no-build` to update lock data and verify evaluation.
4. Re-ran the same check a second time to remove one-time lock/network overhead and measure steady-state timing.

## Decisions and reasoning
- Added a root `rust-overlay` input so both `yazi` and `fff-nvim` can follow one shared node.
- Converted one-line inputs (`yazi`, `fff-nvim`, `neovim-nightly-overlay`, `nixpkgs-firefox-darwin`) into attrsets to attach `inputs.*.follows`.
- Used `nix flake check --no-build` for timing because it captures flake evaluation and is safe/fast enough to compare before vs after dedupe.

## Timing notes
- Baseline (before edits): `real 7.022`.
- First run after edits: `real 9.605` (includes lock updates and initial fetch of newly introduced top-level input wiring).
- Steady-state after lock settled: `real 6.303`.

## Learning points
- Deduplication improves steady-state eval time, but first run can be slower when lock graph changes trigger fetch/update work.
- A shared top-level input plus `follows` is cleaner than making one dependency follow another transitive dependency path.

## Issues and fixes
- `/usr/bin/time` was unavailable in this environment; switched to Bash built-in timing via `TIMEFORMAT` and `time`.
