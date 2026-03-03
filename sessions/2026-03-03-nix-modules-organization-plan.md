# 2026-03-03 - nix-modules-organization-plan

## Task

Design a target `nix/modules/` structure from use cases in `sessions/2026-03-01-use-cases.md`, prioritizing composability, deduplication, and extensibility while preserving project constraints:

- Every file is a flake-parts module (import-tree discovered).
- No path-based aggregator imports.
- `nix/outputs/` remains output generator layer.
- `nix/configs/` remains host/user/machine atomic config layer.

## Retrieval performed

- Read use-cases source: `sessions/2026-03-01-use-cases.md`.
- Read current flake wiring and output generation:
  - `flake.nix`
  - `nix/imports.nix`
  - `nix/outputs/{nixosConfigurations,darwinConfigurations,allowedUnfreePackages,packages,devShells}.nix`
- Read host config layer:
  - `nix/configs/{alpha,nemesis}.nix`
- Read all current module files under `nix/modules/**/*.nix`.
- Ran subagents for:
  - Very thorough codebase structural audit.
  - Web research on flake-parts/import-tree/HM module structuring patterns.
- Retrieved supporting docs from:
  - flake-parts best practices
  - import-tree dendritic guide
  - Home Manager manual (NixOS + Darwin module integration notes)

## Key findings

- Current structure already follows dendritic style and one-file-per-concern mostly well.
- Existing strong base patterns:
  - Shared account model (`flake.accounts.rafiq`).
  - Shared `modules.{nixos,darwin}.default` baseline.
  - Shared allowUnfree policy fanout.
  - Shared HM entrypoint (`modules.homeManager.rafiq`).
- Main structural issues:
  - Darwin host-level modules in `nix/configs/alpha.nix` are currently ignored by `nix/outputs/darwinConfigurations.nix` (host list is not appended like NixOS path).
  - Mixed naming conventions (`snake_case` + `kebab-case`).
  - Some cross-platform duplication in module bodies (especially HM bootstrap and security wrappers).
  - Domain folders mix intent axes (platform, concern, user identity).

## Proposed direction captured for report

- Introduce explicit layering in `nix/modules/`:
  - `00-schema` (flake options + data model)
  - `10-foundation` (shared nixpkgs/nix/identity/security glue)
  - `20-concerns` (concern-centric modules, with NixOS + Darwin + HM defined together per concern where relevant)
    - Categorized into `services/`, `cli/`, and `desktop/`
    - Darwin-only disambiguation via `darwin-<concern>.nix`
  - `40-profiles` (reusable bundles e.g. workstation/base)
  - `90-policies` (assertions and repo-wide policy checks)
- Keep host-specific assembly in `nix/configs/*` using `cfg.modules.*` references.
- Prefer extracting shared attrsets/functions for cross-platform parity.
- Keep helper internals in underscore-prefixed dirs where needed.

## Planned file tree (revised)

```text
nix/modules/
  00-schema/
    accounts.nix
    hosts.nix
    systems.nix

  10-foundation/
    paths.nix
    nix-settings.nix
    state-defaults.nix
    home-manager-bootstrap.nix
    allow-unfree-policy.nix

  20-concerns/
    services/
      account-rafiq.nix
      security-ssh.nix
      security-sudo.nix
      security-sops.nix
      security-tailscale.nix
      shell-fish.nix
      shell-starship.nix
      git.nix
      app-neovim.nix
      app-ghostty.nix
      app-firefox.nix
      app-yazi.nix
      darwin-homebrew.nix
      darwin-rosetta-builder.nix
      darwin-utilities.nix

    cli/
      productivity.nix
      env-managers.nix
      nix-discovery.nix
      opencode-mcp.nix
      personal-aliases-notes-scripts.nix

    desktop/
      hyprland.nix
      waybar.nix
      pipewire.nix
      nvidia.nix
      steam.nix
      obs.nix
      i2c.nix

  40-profiles/
    profile-nixos-base.nix
    profile-nixos-desktop.nix
    profile-nixos-gaming.nix
    profile-darwin-base.nix
    profile-darwin-workstation.nix
    profile-home-manager-base.nix
    profile-home-manager-dev.nix

  90-policies/
    assertions-desktop-deps.nix
    assertions-host-composition.nix

  _lib/
    mk-shared-hm-user.nix
    mk-account-user-module.nix
    mk-platform-conditionals.nix
```

## Decision notes

- Report-only deliverable in this session (architecture proposal + alternatives), no refactor applied yet.
- Next implementation phase should be staged:
  1. Add missing Darwin host module fan-in in output generator.
  2. Normalize naming and move files by concern layer.
  3. Add profile bundles and shrink host config files.
  4. Add assertions for composition correctness.

## Implementation executed

- Refactored `nix/modules/` into the proposed layered, concern-categorized structure:
  - `00-schema`, `10-foundation`, `20-concerns/{services,cli,desktop}`, `40-profiles`, `90-policies`, `_lib`.
- Migrated all functional module definitions from legacy directories into the new structure and removed legacy files under:
  - `accounts/`, `apps/`, `cli/`, `darwin/`, `desktop/`, `nix/`, `rafiq/`, `security/`, `shell/`.
- Consolidated multi-file concern groups:
  - Git modules -> `20-concerns/cli/git.nix`
  - Yazi modules -> `20-concerns/cli/yazi.nix`
  - Account/user/password-related modules -> `20-concerns/services/account-rafiq.nix`
- Added user-specific HM profile split:
  - `40-profiles/profile-home-manager-rafiq/core.nix`
  - `40-profiles/profile-home-manager-rafiq/desktop-hyprland.nix`
  - `40-profiles/profile-home-manager-rafiq/desktop-waybar.nix`
  - Wired `modules.homeManager.rafiq` to import `modules.homeManager.profileRafiq`.

## Verification run

- Used `scripts/nix-build-diff.sh` as requested.
- Result for `nixosConfigurations.nemesis.config.system.build.toplevel`:
  - HEAD and WORKDIR store paths match exactly.
  - `nvd` reports no version/selection changes and zero closure delta.
- Result for `darwinConfigurations.alpha.system`:
  - Build diff could not complete on this Linux host due missing `aarch64-darwin` builder availability.
  - Failure reason from script output: required system `aarch64-darwin` not available on current builder.
  - Supplementary check: evaluated key alpha config attributes from HEAD and WORKDIR match (host/user/homebrew/ssh/tailscale/HM state values).

## Follow-up constraint update

- User requested to restart planning with a stronger rule: for the same concern, keep NixOS + nix-darwin + Home Manager module definitions together in one file rather than split into platform subfolders.
- Revised plan should therefore be concern-centric with multi-target outputs per file (e.g. `config.flake.modules.nixos.*`, `config.flake.modules.darwin.*`, `config.flake.modules.homeManager.*` defined side-by-side when relevant).

## Follow-up structure adjustment

- User requested concern categories under `nix/modules/20-concerns/` using subfolders like `services/`, `cli/`, and `desktop/`.
- Naming preference:
  - Default file names are concern names (cross-platform where possible).
  - Darwin-specific variants use `darwin-<concern>.nix` within the same category folder to minimize disambiguation.
- Keep all other layering and planning assumptions unchanged for now.
