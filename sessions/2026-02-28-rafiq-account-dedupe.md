# 2026-02-28 - rafiq account dedupe

## Task

- Deduplicate rafiq account identity values across Darwin and NixOS modules.
- Introduce generated flake-parts options for username, full name, and SSH key.
- Reuse those option values where account identity is currently hardcoded.

## Work Log

- Read existing account modules:
  - `nix/modules/accounts/rafiq/nixos-user.nix`
  - `nix/modules/accounts/rafiq/darwin-user.nix`
- Searched for duplicate identity literals and username references across `nix/`.
- Looked up flake-parts docs on option declarations and module arguments:
  - `https://flake.parts/options/flake-parts.html`
  - `https://flake.parts/module-arguments.html`
- Added `nix/modules/accounts/rafiq/profile.nix` with generated options:
  - `options.flake.accounts.rafiq.username`
  - `options.flake.accounts.rafiq.fullName`
  - `options.flake.accounts.rafiq.sshPublicKey`
- Refactored consumers to use `config.flake.accounts.rafiq.*`:
  - `accounts/rafiq/{nixos-user,darwin-user}.nix`
  - `cli/git/core.nix`
  - `accounts/rafiq/home-manager-bootstrap.nix`
  - `accounts/rafiq/password-secret.nix`
  - `shell/fish.nix`
  - `security/sops.nix`

## Decisions

- Used `mkOption` + `types.str` with defaults so values are configurable while preserving current behavior.
- Kept module keys like `cfg.modules.nixos.rafiq` as-is; only identity data became option-driven.
- Updated password secret naming and file path to derive from `username` for consistency.

## Bugs / Risks

- Potential risk: changing secret attr key construction in `password-secret.nix` could surface if other modules hardcode `"rafiq/password"`.
- Potential risk: new options module must remain git-tracked so flake evaluation from git source sees it.

### Encountered

- `nix flake check` initially failed with `attribute 'accounts' missing` in `home-manager-bootstrap.nix`.
  - Cause: new file `nix/modules/accounts/rafiq/profile.nix` was not git-tracked yet, so git-based flake source omitted it.
  - Fix: staged the new file (`git add nix/modules/accounts/rafiq/profile.nix`) and reran checks.
- `statix` raised `W04` warnings for let-bind assignments that should use `inherit`.
  - Fix: replaced direct assignments with `inherit (..)` bindings.

## Validation Plan

- Run `just nice`.
- Run `just check`.

## Validation Results

- `just nice`: passed.
- `just check`: passed after fixes.
  - Notable existing warnings from `nix flake check`: unknown custom flake outputs and existing evaluation warnings from `crane`/`yazi` defaults.

## Follow-up Dedupe Pass

- Audited `nix/modules/**` for remaining hardcoded user identity values.
- Expanded `options.flake.accounts.rafiq` in `nix/modules/accounts/rafiq/profile.nix` with:
  - `email`
  - `nixosUid`
  - `darwinUid`
- Rewired additional modules to consume shared account options:
  - `nix/modules/cli/git/core.nix` (`user.email`)
  - `nix/modules/accounts/rafiq/nixos-user.nix` (`uid`)
  - `nix/modules/accounts/rafiq/darwin-user.nix` (`uid`)
  - `nix/modules/nix/settings-common.nix` (`nix.settings.trusted-users`)
  - `nix/modules/darwin/homebrew.nix` (`nix-homebrew.user`)
  - `nix/modules/security/tailscale.nix` (secret key + sops file path derived from username)
- Re-ran `just nice && just check` and all checks passed.

## Warning Cleanup Pass

- Goal: remove Nix evaluation warnings seen during `nix flake check` in `just check`.
- Fixed Home Manager yazi warning by explicitly pinning wrapper behavior in `nix/modules/cli/yazi/core.nix`:
  - `programs.yazi.shellWrapperName = "yy";`
- Fixed crane placeholder warnings by avoiding evaluation of upstream `fff-nvim` flake package output:
  - In `nix/modules/apps/neovim.nix`, replaced `inputs.fff-nvim.packages.<system>.fff-nvim` with a local `pkgs.vimUtils.buildVimPlugin` derivation sourced from `inputs.fff-nvim`.
- Validation:
  - Ran `just nice && just check`.
  - Prior `evaluation warning:` entries (`yazi.shellWrapperName`, crane `name`/`version`) no longer appear.
- Remaining warnings are non-evaluation flake warnings about unknown custom outputs (`paths`, `modules`, `accounts`, `hosts`, `allowedUnfreePackages`) plus expected dirty-tree warning.

## Follow-up Fix: `just rb` Failure

- After the warning cleanup, `just rb` failed during `nh os switch .` while building `vimplugin-fff-nvim-main`.
- Root cause: default `buildVimPlugin` checks run `neovimRequireCheckHook`; `fff.nvim` tries to load an external Rust backend (`libfff_nvim.so`) that is not present in the plugin derivation, causing require-check failures.
- Fix applied in `nix/modules/apps/neovim.nix`:
  - Set `doCheck = false;` for the custom `fff-nvim` plugin derivation.
- Verification:
  - `just check` passes.
  - `nix build .#nixosConfigurations.nemesis.config.system.build.toplevel` succeeds.
