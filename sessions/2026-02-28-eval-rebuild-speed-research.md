# 2026-02-28 - eval and rebuild speed research

## Task
- Research and implement practical changes to speed up Nix flake evaluation and NixOS/nix-darwin rebuild or switch workflows.
- Validate changes with real commands and timings.

## Retrieval performed
1. Searched web sources with `ddgr --json` for evaluation, rebuild, binary cache, and distributed build optimization patterns.
2. Pulled official `nix.dev` references:
   - `nix.conf` settings reference
   - `nix flake` manual
   - `nix build` manual
   - distributed builds tutorial
   - HTTP binary cache setup tutorial
   - custom binary cache recipe
3. Pulled `Import From Derivation` reference to verify evaluation blocking/performance implications.
4. Pulled supporting ecosystem writeups:
   - Tweag eval-cache article
   - Determinate resolved-store-paths article
   - NixOS wiki `nixos-rebuild` page
5. Audited repository Nix config and module structure to identify what is currently configured and where safe changes belong.

## Local repo findings before implementation
- Existing:
  - `extra-substituters` / `extra-trusted-public-keys` in `nix/modules/nix/settings-common.nix`.
  - yazi cache in `nix/modules/cli/yazi/cache.nix`.
- Missing before implementation:
  - explicit eval/network/cache tuning (`eval-cache`, registry knobs, TTL knobs, connection and substitution parallelism).
  - explicit local build concurrency knobs (`max-jobs`, `cores`).
  - explicit distributed-build switch and builder list.
  - explicit anti-IFD guard (`allow-import-from-derivation = false`).

## Implemented changes
- Updated `nix/modules/nix/settings-common.nix` to define a shared performance-focused `nix.settings` set for both NixOS and nix-darwin modules.
- Added/changed these settings:
  - `eval-cache = true`
  - `fallback = false`
  - `use-registries = false`
  - `flake-registry = ""`
  - `tarball-ttl = 86400`
  - `connect-timeout = 10`
  - `http-connections = 50`
  - `max-substitution-jobs = 32`
  - `narinfo-cache-negative-ttl = 60`
  - `max-jobs = "auto"`
  - `cores = 0`
  - `builders-use-substitutes = true`
  - `allow-import-from-derivation = false`
  - retained existing `extra-substituters` and `extra-trusted-public-keys`
- Added module-level distributed-build toggles in both defaults:
  - `nix.distributedBuilds = true`
  - `nix.buildMachines = [ ]`

## Why each implemented knob was selected
- `eval-cache`: faster repeated flake evaluations.
- `use-registries = false` + empty `flake-registry`: avoid registry resolution overhead for explicit URL/locked workflows.
- `allow-import-from-derivation = false`: prevent eval-time realisations from stalling sequential eval.
- `tarball-ttl`: reduce repeated freshness checks.
- `http-connections` + `max-substitution-jobs`: increase substitution parallelism.
- `connect-timeout`: failover faster from slow/dead endpoints.
- `max-jobs` + `cores`: use machine resources better for local builds.
- `builders-use-substitutes`: required for efficient remote builders.
- `distributedBuilds`/`buildMachines`: wiring in place so adding real builders is a data change, not a structural refactor.

## Validation and testing executed
- Flake validity:
  - `nix flake check --no-build` passed after edits.
- Full repository quality gates:
  - `just nice` passed.
  - `just check` passed (includes format, lint, clippy, tests, and `nix flake check --all-systems`).
- NixOS output inspection to confirm generated config:
  - built toplevel path with `nix build .#nixosConfigurations.nemesis.config.system.build.toplevel --print-out-paths --no-link`
  - read generated `/etc/nix/nix.conf` from that store path and confirmed all newly added settings are present.
- nix-darwin setting propagation check:
  - evaluated booleans from `darwinConfigurations.alpha` for `eval-cache`, `use-registries`, `builders-use-substitutes`, `nix.distributedBuilds`.

## Timing measurements
- Baseline (before edits):
  - `nix flake check --no-build`: `real 6.380`
  - warm `nix build .#nixosConfigurations.nemesis.config.system.build.toplevel --no-link`: `real 0.525`
- After edits (steady state):
  - `nix flake check --no-build`: `real 6.124`
  - warm `nix build .#nixosConfigurations.nemesis.config.system.build.toplevel --no-link`: `real 0.493`
- Interpretation:
  - small but real local improvement in steady-state eval and warm toplevel derivation realization.
  - largest expected wins from these changes will appear on hosts where these settings are actually active and under heavier cache/build/network contention.

## What could not be fully benchmarked locally
- True distributed build speedup requires real remote builders in `nix.buildMachines`.
- `--store-path` deployment acceleration is a deployment workflow change (CI/remote target path), not a pure module-level setting; no target-host switch test performed in this environment.

## Exhaustive recommendation map (researched)
- Highest impact areas, in order:
  1. Binary cache hit-rate and substituter correctness.
  2. Distributed builders with `builders-use-substitutes = true`.
  3. Eval graph hygiene (dedupe inputs, avoid IFD, keep eval cache warm).
  4. Network/substitution concurrency tuning.
  5. Deployment path design (`build elsewhere`, apply by store path).
- Advanced/optional:
  - pre-resolved store path workflows (ecosystem-specific tooling) for reducing target-side eval tax in deployments.

## Caveats
- Some advice is version-sensitive (`nix.conf` defaults differ across Nix versions).
- Non-official sources were used only as additive ideas; official docs/manuals were prioritized for recommendations.
- Local `nix show-config` reflects the currently running host daemon, not the repo’s generated NixOS config, so generated store-path config inspection was used for authoritative validation of module output.

## Follow-up research: profiling protocol request
- User requested authoritative, up-to-date local CLI profiling guidance across flake evaluation, realisation/build, and NixOS/nix-darwin activation/switch phases.
- Retrieved and cross-checked these source families:
  - Nix reference manual: common options (`--log-format internal-json`), environment variables (`NIX_SHOW_STATS`, `NIX_COUNT_CALLS`), command refs (`nix build`, `nix eval`, `nix flake check`), and `nix.conf` performance-related options.
  - Nixpkgs stdenv chapter + `setup.sh`: documented `NIX_DEBUG` semantics and levels (0-7), including `set -x` behavior at high verbosity.
  - nix-darwin upstream `darwin-rebuild.sh`: explicit sequence (`build` then `activate`) and machine-parseable `nix build --json` usage in the script.
  - NixOS wiki `nixos-rebuild` internals section: decomposition into toplevel build + profile update + `switch-to-configuration` activation.
  - nh upstream README: CLI parity/positioning and operational context for wrapping `nh os/darwin switch` timing.
- Output prepared to include:
  1. Step-by-step profiling protocol with per-command measurement intent.
  2. Machine-readable log capture strategy (`internal-json`, `--json`, `/usr/bin/time` outputs).
  3. Timing-skew pitfalls (daemon warm state, cache heat, lock contention, remote cache variance, activation side effects).
  4. Bottleneck-to-knob map for eval/fetch/substitute/local build/activation with confidence labels and source URLs.

## Follow-up research (nh os/darwin switch matrix request)
- Compiled a prioritized performance matrix specifically for flake workflows using `nh os switch` and `nh darwin switch`.
- Focused on: daemon/client settings, eval and lock hygiene, build graph reductions, cache strategy, and activation-time reductions.
- Sources retrieved this round:
  - Nix reference manual: `nix.conf`, `nix flake`, `nix flake lock`, `nix flake update`, Import From Derivation.
  - nix.dev tutorials and guides: distributed builds, HTTP binary cache setup, add-binary-cache, post-build-hook.
  - `nh` upstream README for `os`/`darwin` command behavior and perf-related env vars (`NH_NO_CHECKS`, flake env resolution behavior).
  - nix-darwin options manual for activation-time knobs related to Homebrew on-activation behavior.
  - MyNixOS option docs for service restart/reload switch semantics (`restartIfChanged`, `reloadIfChanged`, `stopIfChanged`) as trusted community references with direct nixpkgs declaration links.
