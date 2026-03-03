## Task

Suggested a potential end-state layout for splitting `nix/modules/` by domain, with a first-pass extraction of user-specific config into `nix/modules/rafiq/` and one-responsibility-per-file organization.

## Repo Exploration

- Read all current files in `nix/modules/` to identify ownership and concerns.
- Confirmed `flake.nix` uses `import-tree ./nix`, so file moves inside `nix/` are generally safe as long as exported option paths remain stable.
- Reviewed project conventions in `.agents/skills/nix/SKILL.md` (module wiring via `config.flake.modules.*`, avoid direct path imports).

## Reasoning And Decisions

- Chose a minimal-churn migration strategy: keep existing module keys (`cfg.modules.homeManager.rafiq`, `cfg.modules.nixos.*`, `cfg.modules.darwin.*`) while only changing file layout and splitting mixed-responsibility files.
- Identified that many files currently mix personal and system concerns (notably `build_users.nix`, `fish.nix`, `hyprland.nix`, `firefox.nix`, `ghostty.nix`, `yazi.nix`, `tailscale.nix`).
- Recommended extracting user-specific pieces to `nix/modules/rafiq/` first, then optional second-pass split by platform/domain.

## Proposed End State (high level)

- `nix/modules/rafiq/` for personal HM + personal OS glue.
- `nix/modules/system/` for machine-agnostic OS defaults.
- `nix/modules/hardware/` for hardware/vendor modules.
- `nix/modules/roles/` for host-role modules (desktop/audio/gaming).

## Learning Points

- This repository’s `import-tree` setup enables aggressive module file re-organization without changing explicit import lists.
- Existing project convention strongly favors one responsibility per file and wiring through `cfg.modules.*` namespaces.

## Bugs Encountered

- None.

## Outcome

- Prepared an actionable target structure and migration approach for extracting `rafiq`-specific config cleanly.

## Follow-up

- Added a concise `nvd`-based regression-check workflow to `.agents/skills/nix/SKILL.md` for before/after refactor validation, with `nix flake check` as a companion guard.

## Implementation Update

- Refactored `nix/modules/aliases.nix` into three domain-scoped modules under `nix/modules/rafiq/`.
- Created `nix/modules/rafiq/aliases.nix` for editor/selection aliases (`v`, `e`).
- Created `nix/modules/rafiq/scripts-utils.nix` for script packaging (`fooc` via `writeShellScriptBin`).
- Created `nix/modules/rafiq/note-taking.nix` for note workflow aliases (`lib`, `process`, `day`, `month`).
- Deleted original mixed-concern `nix/modules/aliases.nix`.
- Corrected module style to omit empty lambda headers for arg-less modules.
- Removed path-based aggregator module attempt and relied on import-tree file discovery.
- Ensured new `nix/modules/rafiq/*` files are git-tracked so flake git source includes them.

## Rationale

- Kept exported option path unchanged (`config.flake.modules.homeManager.rafiq`) to preserve host wiring and behavior.
- Split by concern so each file now owns one domain (aliases vs scripts vs note-taking).

## Regression Verification

- Compared clean `HEAD` vs dirty working tree for `.#nixosConfigurations.nemesis.config.system.build.toplevel` using `nvd`.
- Initial run showed removed `fooc` because new files were untracked; after tracking files and removing aggregator import approach, re-ran diff.
- Final `nvd` result: `No version or selection state changes.` and closure size unchanged (`2090 -> 2090`).

## Implementation Update (Full Modules Refactor)

- Added `scripts/nix-build-diff.sh` to automate clean-`HEAD` vs working-tree builds and `nvd` diffs.
- Reorganized `nix/modules/` into domain folders to make ownership explicit:
  - `apps/`, `cli/`, `darwin/`, `desktop/`, `security/`, `shell/`, `accounts/rafiq/`, `nix/`, `rafiq/`.
- Split mixed-concern modules into one-domain-per-file:
  - `build_users.nix` -> `accounts/rafiq/{home-manager-bootstrap,nixos-user,darwin-user,password-secret,sudo-policy}.nix`
  - `git.nix` -> `cli/git/{core,aliases}.nix`
  - `hyprland.nix` -> `desktop/hyprland/{nixos-core,home-manager-core,home-manager-layout,home-manager-keybinds}.nix`
  - `yazi.nix` -> `cli/yazi/{core,path-from-root-plugin,plugin-test-hook,alias,cache}.nix`
  - `nix_config.nix` -> `nix/{settings-common,darwin-system}.nix`
- Moved all remaining single-responsibility modules into matching domain directories without behavior changes.

## Bugs Encountered And Fixes

- `cfg.modules.nixos.hyprland` missing during `nix flake check`:
  - Cause: new split files were untracked and therefore omitted from git-source evaluation.
  - Fix: stage newly added files under `nix/modules/` before running checks.
- `attribute 'users' missing` in Home Manager bootstrap:
  - Cause: used flake-level `config` where module-level `config` was required.
  - Fix: converted `modules.{nixos,darwin}.default` definitions to function modules (`{ config, ... }:`).
- `attribute 'sops' missing` in password module:
  - Cause: same config scoping issue.
  - Fix: converted `modules.nixos.default` in `password-secret.nix` to function module.

## Final Verification

- Ran `just nice` and `just check` successfully after refactor.
- Ran `scripts/nix-build-diff.sh` for `nixosConfigurations.nemesis.config.system.build.toplevel`.
- Final `nvd` result remained clean:
  - `No version or selection state changes.`
  - closure size unchanged: `2090 -> 2090`.
