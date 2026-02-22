# AGENTS.md

## Scope

Reusable modules for NixOS, nix-darwin, and home-manager.

## File Index

- Core shell/editor/dev: `fish.nix`, `git.nix`, `neovim.nix`, `starship.nix`, `zoxide.nix`, `yazi.nix`.
- Platform/runtime: `docker.nix`, `pipewire.nix`, `hyprland.nix`, `nvidia.nix`, `steam.nix`, `rosetta_builder.nix`.
- Security/secrets: `sops.nix`, `ssh.nix`, `build_users.nix`.
- Utilities: `aliases.nix`, `direnv.nix`, `gh.nix`, `mcp.nix`, `mise.nix`, `ripgrep_all.nix`, and others.

## Rules

- Keep one responsibility per module file.
- Add assertions for required dependencies where useful.
- Keep secret wiring consistent with `sops/` and `build_users.nix` patterns.
- Prefer module composition over per-host duplication.
