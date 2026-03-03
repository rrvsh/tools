# 2026-03-01 - fff-nvim revert + flake input update

## Task

- Revert the local `fff-nvim` packaging change in `nix/modules/apps/neovim.nix`.
- Update flake inputs and check whether evaluation warnings still appear.

## Changes made

- Reverted `fff-nvim` wiring to use upstream flake package output directly:
  - `inputs.fff-nvim.packages.${pkgs.stdenv.hostPlatform.system}.fff-nvim`
- Removed the temporary local plugin build toggle (`useUpstreamFffNvim`) and the custom `buildVimPlugin` branch.

## Commands run

- `nix flake update`
  - Succeeded and updated many inputs, including `fff-nvim`.
- `nix flake check --no-build`
  - Still reports evaluation warnings:
    - `warning: unknown flake output 'paths'`
    - `warning: unknown flake output 'modules'`
  - Then fails while checking `nixosConfigurations.nemesis` with:
    - `error: path '/nix/store/vhmvxc0zq625n6gzgfrrzxcv4h45ayg2-source' is not valid`

## Reasoning and decisions

- The runtime error in Neovim pointed at missing compiled Rust backend library paths in `fff-nvim`.
- Reverting to upstream package output is aligned with project conventions and avoids local plugin build drift.
- Input update was executed to test whether newer locked revisions alter evaluation behavior.

## Findings

- The evaluation warnings still occur after reverting `fff-nvim` wiring and updating flake inputs.
- The specific warnings observed are about non-standard flake outputs (`paths`, `modules`), not directly about `fff-nvim`.
- There is also a separate evaluation error for an invalid store path during `nixosConfigurations.nemesis` check.

## Follow-up ideas

- Re-run with `nix flake check --no-build --show-trace` to pinpoint where the invalid store path is introduced.
- If desired, run a focused eval on the Neovim/Home Manager path only to isolate from unrelated NixOS host issues.

## Additional debugging performed

- Ran `nix flake check --no-build --show-trace`.
  - Trace showed invalid store path now originating during Home Manager manpath generation.
  - Deep stack trace pointed to Yazi Rust vendoring path:
    - `readFile /nix/store/...-source/Cargo.lock`
    - error path: `/nix/store/17dylgbdsqa2imvsc2q6mzfanhlgmg7w-source`
- Built Hyprland input directly (`nix build github:hyprwm/Hyprland/<rev>#packages.x86_64-linux.hyprland --no-link`) to confirm earlier Hyprland-related trace branch was not the blocking issue.

## Resolution applied

- Pinned `yazi` input back to previous lock revision:
  - from `3cdc3ecb70c13da9325b8333dca8514a53bcbdc3`
  - to `bfa1e535842c77c653c4381ce8c44b4a1ef65a0d`
- Updated Neovim module binding style to satisfy statix:
  - `inherit (inputs.fff-nvim.packages.${pkgs.stdenv.hostPlatform.system}) fff-nvim;`

## Verification

- `just check` now passes end-to-end (warnings about unknown custom flake outputs remain expected):
  - `paths`, `modules`, `accounts`, `hosts`, `allowedUnfreePackages`
- Successful NixOS build achieved (without switching):
  - `nix build .#nixosConfigurations.nemesis.config.system.build.toplevel --no-link --print-out-paths`
  - output: `/nix/store/1cavkvkpbac41qfmfx111xqb8vsh5mhp-nixos-system-nemesis-26.05.20260227.dd9b079`
