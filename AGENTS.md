# Agent Guidelines for rrvsh/tools

Note: Emphasis (bold/italic) should not be used in AGENTS.md files. Use plain text only.

## Project Overview

This is a NixOS/darwin/home-manager configuration repository with a Rust web server (rs/site/). The project uses:
- Nix for system configuration (flake-parts modules)
- Rust (Axum web framework with Askama templates)
- Lua for Neovim configuration
- Terraform/OpenTofu for infrastructure
- GitHub Actions for CI

All commands run via `just` from the repository root.

## Common Commands

```bash
just check        # Run all checks + tests
just nice         # Format + lint everything
just test         # Run all tests
```

## Language-Specific Guides

For detailed code style guidelines, see:
- nix/AGENTS.md - Nix configuration
- rs/site/AGENTS.md - Rust web server
- nvim/AGENTS.md - Neovim/Lua configuration
- tf/AGENTS.md - Terraform/OpenTofu

## File Structure

```
/home/rafiq/1_repos/tools/
├── AGENTS.md              # This file
├── flake.nix              # Flake definition
├── Justfile               # Task runner
├── nix/                   # Nix configurations
│   ├── AGENTS.md          # Nix code style
│   ├── flake-parts/       # flake-parts modules
│   ├── hosts/             # Host-specific NixOS/darwin configs
│   └── packages/          # Package definitions
├── rs/                    # Rust workspace
│   └── site/              # Web server (Axum + Askama)
│       └── AGENTS.md      # Rust code style
├── tf/                    # Terraform/OpenTofu configs
│   └── AGENTS.md          # Terraform code style
├── nvim/                  # Neovim configuration
│   └── AGENTS.md          # Lua code style
├── sops/                  # SOPS secrets (age encrypted)
└── .env                   # Environment variables
```

## Development Workflow

1. Make changes to the appropriate language/area
2. Run `just nice` to format and lint
3. Run `just check` to verify all checks pass
4. Commit and push (CI will run on PR)
