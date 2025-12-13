# Declarative Per-User Folder Orchestration

- Status: Draft
- Date: 2025-12-13

## Context

I want a single, declarative source of truth in my flake that ensures the important folders in my home directory always exist and behave the way I expect. Home Manager already gives me a Syncthing module (`services.syncthing`) that can declare folders, devices, and ignore patterns (Syncthing reads `.stignore` for that), so Syncthing is the first built‑in sync backend I should lean on ([MyNixOS option docs](https://mynixos.com/home-manager/option/services.syncthing.settings.folders), [NixOS Syncthing wiki](https://nixos.wiki/wiki/Syncthing)). Syncthing needs stable folder IDs and explicit device sharing; if I forget to share a folder with a device, that folder just sits inactive, so validation must catch “unshared” definitions ([MyNixOS folder options](https://mynixos.com/home-manager/option/services.syncthing.settings.folders.%3Cname%3E)). Git automation run under sudo/root hits the Git safety check (CVE‑2022‑24765); I have to set `safe.directory` at the repository root to avoid “unsafe repository” errors ([Git advisory](https://github.com/git/git/security/advisories/GHSA-j342-m5hw-rr3v)). For offloading data, Home Manager already knows how to define rclone remotes and mounts (`programs.rclone.remotes.*.mounts.*`); on macOS that depends on macFUSE or FUSE‑T being installed and allowed ([MyNixOS rclone mounts](https://mynixos.com/home-manager/option/programs.rclone.remotes.%3Cname%3E.mounts), [rclone mount docs](https://rclone.dev/commands/rclone_mount/)). Safety is non‑negotiable: if something looks unsafe, the rebuild should stop instead of guessing. Mode combinations have to be explicit and validated. I still want the design to leave room for future backends without breaking my current setups.

## Decision

Add a typed list of folder specs to the flake options for my user. Each folder entry names the path and one or more modes (git, sync, offload) plus their settings (remote URL, branch, ignores, schedule, backend, safety flags, permissions). The Home Manager module should always try native units first (Syncthing folders, rclone mounts) and only drop to custom activation code when nothing native exists—this follows my “prefer native module” rule. Mode combos are allowed only when I explicitly enable them (git + sync, git + sync + offload). Safe defaults apply, like ignoring `.git` in Syncthing, with an opt‑out if I need hooks or submodules to sync. Unsupported or unsafe combos fail validation. Rebuild/apply stays the only command I run; platform prerequisites (for example macFUSE for rclone on macOS) must be present or the build fails early ([rclone mount macOS notes](https://rclone.dev/commands/rclone_mount/)).

## Consequences

- Positive: One source of truth; rebuild makes folders match the spec; I reuse Syncthing and rclone modules instead of inventing everything; preflight checks make automation safer; the interface leaves room to add more modes later.
- Negative: Rebuild gets a bit slower due to validation; composition rules add mental overhead; strict aborts may interrupt quick edits.
- Risks: Bad remote definitions or missing dependencies will stop the apply; Syncthing’s service does not add the CLI by default, so I must include the package (see [Syncthing HM discussion](https://discourse.nixos.org/t/syncthing-in-home-manager-does-not-have-datadir-option/28427/2)); rclone mounts need macFUSE/FUSE‑T on macOS ([rclone mount macOS requirements](https://rclone.dev/commands/rclone_mount/)); any scheduled automation must refuse to run on dirty Git trees or unreachable remotes to avoid data loss.

## Alternatives Considered

- Manual scripting per user: rejected—non-declarative, hard to audit, brittle across hosts.
- Single-mode-only design: rejected—limits real workflows (e.g., repo plus device sync).
- Post-build continuous controller: rejected for now—adds runtime overhead and observability surface; build-time guarantees are sufficient.

## Implementation Plan

- Define schema under `nix/options/users/folders.nix` (paths, modes, backends, branch, ignores, schedule, permissions, safety flags). Use enums for known backends (`git`, `syncthing`, `rclone-offload`). State upfront that vendor clouds like Dropbox/OneDrive are out of scope for v1.
- Implement interpreter logic in the matching Home Manager module to emit native units first:
  - Sync mode → `services.syncthing` entries with required `id`, `devices`, and `ignorePatterns`; fail if devices are empty or IDs collide. Syncthing stores config in its own dir; each folder carries its own path, so there is no per-folder `dataDir` knob ([MyNixOS Syncthing folder options](https://mynixos.com/home-manager/option/services.syncthing.settings.folders.%3Cname%3E)). 
  - Offload mode → user systemd/launchd units using `programs.rclone.remotes.*.mounts.*` for mount semantics, or `rclone move/sync` followed by symlink swap when eviction is desired; destructive flags (like `--delete-during`) remain opt-in. On macOS, require macFUSE/FUSE‑T and fail validation if missing ([rclone mount docs](https://rclone.dev/commands/rclone_mount/)). 
- Git mode: make the directory, clone or init + set origin, set `safe.directory` at repo root, respect branch choice, and only pull/push on a clean tree and fast‑forward path; clearly state auth expectations (SSH agent or token) ([Git advisory](https://github.com/git/git/security/advisories/GHSA-j342-m5hw-rr3v)). 
- Composition rules: by default ignore `.git` in Syncthing to avoid churn; allow opt‑out when I need Git metadata synced. Precedence: git (ensure clean) → sync (propagate) → offload (evict). For offload+sync, probe the remote (`rclone ls`/`lsd`) first, then move data and swap to a symlink with atomic rename so I can roll back safely ([rclone mount docs](https://rclone.dev/commands/rclone_mount/)). 
- Validation: check for origin/branch mismatch, dirty Git trees before scheduled actions, unreachable remotes (use minimal `rclone lsd` probe), missing Syncthing devices or duplicate folder IDs, unsupported mode mixes, and not enough disk space for initial clone/sync.
- Scheduling: stick to one format (systemd `OnCalendar` / launchd cron-style) and reject bad schedules at eval time.
- Packaging & ordering: enabling Syncthing or rclone modes also adds their binaries to `home.packages` and wires units with `Requires=`/`After=` so services start after the binaries are present.
- Secrets: require remotes/credentials to live in SOPS-managed files or via agents; never embed secrets in the flake.
- Merge semantics: folder specs merge by path with last-wins override and per-mode deep merge; conflicting duplicates fail validation.
- LFS & large repos: optionally run `git lfs install --local` when `git.mode.lfs = true`; check free space before clone or offload.

## Related Documents

- ADR-000 Template (this repository)
- Nix flake user module definitions (existing user modules)
- Sync/offload backend documentation (e.g., Syncthing, rclone)

## Stakeholders

- Requester: rafiq
- Implementers: tooling maintainers / contributors
- Affected users: all users declaring per-folder behaviors in their flake configs

## Follow-up

- Decide initial backend support priority (Syncthing, rclone) and abstractions for future backends.
- Specify default schedules and safe defaults for destructive flags.
- Add tests/CI checks for validation logic and dry-run paths.
