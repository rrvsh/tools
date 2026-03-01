# Rebuild/Switch Profiling and Optimization (NixOS + nix-darwin)

## Objective

Create an exhaustive, phase-by-phase profiling plan for configuration rebuild/switch workflows, execute profiling runs on this branch, identify real bottlenecks, and test concrete optimizations in-repo.

Scope constraints used for this session:

- Actual rebuild/switch execution done via `just rb`.
- Additional non-switch profiling done via `nix eval` / `nix build` / `nix flake check` to isolate phases.

## Full Profiling Plan (Reusable)

### Phase model

For both NixOS and nix-darwin, profile these phases separately before looking at end-to-end:

1. Flake/module evaluation
2. Build planning (`--dry-run --json`)
3. Realization (substitute/build) without activation
4. Activation/switch
5. End-to-end wrapper (`just rb`)

### Case matrix

Run each phase in these scenarios:

- `no-op hot`: same config, repeated runs
- `no-op cold-like`: disable eval cache (`--option eval-cache false`) and re-run eval/check phases
- `config-only change`: option change that alters system derivation but does not intentionally add package payload
- `package graph change`: add/remove package in module graph
- `cross-system eval`: Linux host plus Darwin output eval/planning

### Measurement protocol

- Use shell `time` (`TIMEFORMAT`) for stable wall/user/sys capture.
- Capture command output/stderr into files under `sessions/profiles/2026-02-28-rebuild-switch/`.
- Use `--log-format internal-json` where possible for machine-readable logs.
- For evaluator characteristics, collect `NIX_SHOW_STATS=1` output.

## Commands Executed

### Evaluation and plan/realization isolation

- `nix eval --raw .#nixosConfigurations.nemesis.config.system.build.toplevel.drvPath`
- `nix eval --raw .#darwinConfigurations.alpha.system.drvPath`
- Same with `--option eval-cache false`
- `nix build .#nixosConfigurations.nemesis.config.system.build.toplevel --dry-run --json`
- `nix build .#nixosConfigurations.nemesis.config.system.build.toplevel --no-link --print-out-paths`
- `nix build .#darwinConfigurations.alpha.system --dry-run --json`

### End-to-end and decomposition

- `just rb` (multiple hot runs)
- `just nice`
- `just check`
- Component timing:
  - `just check-gha`
  - `just check-lua`
  - `just check-nix`
  - `just check-rs`
  - `just test-nix`
  - `just test-rs`

### Flake-check isolation

- `nix flake check --all-systems --no-build`
- `nix flake check --all-systems`
- `nix flake check --system x86_64-linux --no-build`
- `nix flake check --system aarch64-darwin --no-build`
- Cold-like eval variants with `--option eval-cache false`
- `NIX_SHOW_STATS=1 nix flake check --all-systems --no-build`

## Baseline Findings

### High-level timings

- `just rb` hot baseline: `19.179s` (run2; run1 was `23.354s`)
- `just nice`: `3.548s`
- `just check`: `13.768s`

This shows most `just rb` time is pre-switch checks/lint/tests, not the switch itself.

### `just check` bottleneck decomposition

- `check-gha`: `2.070s`
- `check-lua`: `0.011s`
- `check-nix`: `0.464s`
- `check-rs`: `0.495s`
- `test-rs`: `0.115s`
- `test-nix`: `10.925s`  <-- dominant

### Why `test-nix` dominates

- `nix flake check --all-systems --no-build`: `7.567s`
- `nix flake check --all-systems`: `11.093s`
- Single-system no-build:
  - linux: `5.912s`
  - darwin: `6.111s`

The local rebuild path pays cross-system check cost (`--all-systems`) every run.

### Eval/planning observations

- NixOS eval drvPath: `~8.97s`
- Darwin eval drvPath: `~25.79s`
- NixOS dry-run planning: `0.039s`
- NixOS realization (no activation): `0.482s`
- Darwin dry-run planning from Linux host: `19.615s`, with very large derivation/fetch plan (492 drv, 1515 paths)

### Cold-like eval check

Using `--option eval-cache false` had negligible change in this repo for flake-check no-build runs:

- local no-build cold-like: `5.971s`
- all-systems no-build cold-like: `7.515s`

## Optimization Experiments in Repo

## 1) Local-vs-all-systems check gating (kept)

Changed `Justfile` `test-nix` target to:

- default local: `nix flake check`
- opt-in global: `ALL_SYSTEMS=1 just test-nix` -> `nix flake check --all-systems`

Result:

- `just rb` hot with this change: `15.768s`
- `just rb` final validation run: `15.615s`
- Improvement vs baseline hot (`19.179s`): about `-3.56s` (~18.6%)
- `ALL_SYSTEMS=1 just test-nix`: `10.474s` (preserves full cross-system path when desired)

Why this helps:

- The dominant local bottleneck was cross-system checking in `test-nix`.
- Local rebuild/switch feedback loop improves while retaining explicit full-check mode.

## 2) NH checks bypass (`NH_NO_CHECKS=1`) (reverted)

Experimented with setting `NH_NO_CHECKS=1` in `_rb-*` targets.

Observed effect:

- No consistent speedup beyond run-to-run noise.
- Adds safety-tradeoff.

Decision:

- Reverted this optimization.

## Type-of-change profiling results

With local-check optimization in place, `just rb` timing by change type:

- `no-op hot`: `15.6s` to `16.1s`
- `config-only change` (temporary `connect-timeout` tweak):
  - first run: `29.986s`
  - subsequent hot: `16.559s`
- `package graph change` (temporary `pkgs.hello` addition):
  - first run: `34.260s`
  - subsequent hot: `15.950s`

Interpretation:

- First run after graph-changing edits pays rebuild/activation costs.
- Once realized/switched, no-op timings return to the hot baseline window.

## Key Bottlenecks Identified

1. Primary local bottleneck: `test-nix` (`nix flake check --all-systems`) within `just check`.
2. Secondary: `check-gha` (~2s), still much smaller.
3. Switch/activation cost appears comparatively small on no-op runs in this environment.
4. Darwin output evaluation/planning from Linux host is expensive and not representative of native darwin switch.

## What changed in code

- `Justfile`
  - `test-nix` now supports local-fast default and `ALL_SYSTEMS=1` override.

No other experimental config changes were kept.

## Follow-up ideas (next experiments)

- Add a dedicated target split:
  - `just check` (local-fast)
  - `just check-full` (all-systems), and use full path in CI/nightly.
- Add a profiling recipe (`just profile-rb`) to automatically capture phase timings/logs into timestamped directories.
- On a macOS runner, run the same matrix for native `just rb` to measure actual darwin activation bottlenecks (Homebrew/launchd path).
