## Task

Research best practices for organizing large Nix flakes using flake-parts and multi-target modules (NixOS, nix-darwin, home-manager), with concrete guidance tailored to this repository.

## Retrieval Work Performed

- Read project conventions and constraints from `AGENTS.md`, `.agents/skills/web-search/SKILL.md`, and `.agents/skills/nix/SKILL.md`.
- Inspected repository structure and current Nix architecture (`flake.nix`, `nix/imports.nix`, `nix/outputs/*`, `nix/configs/*`, and representative modules under `nix/modules/*`).
- Gathered web sources across official docs and community writeups:
  - flake-parts docs (`Introduction`, `Best Practices for Module Writing`, `Define a Module in a Separate File`, `Module Arguments`, `Dogfood a Reusable Module`, `flake-parts.modules` options)
  - import-tree docs (`Quick Start`, `Motivation`, `Dendritic Pattern`, `API Reference`)
  - Home Manager manual (24.11) sections on NixOS/nix-darwin module integration and `useGlobalPkgs`, `osConfig`
  - Official NixOS Wiki flake-parts page
  - Community examples for host/role/profile structure (CertifiKate and Unmoved Centre articles)
  - nixos-unified specialArgs page for unified cross-target argument conventions

## Key Findings and Reasoning

1. The repository is already aligned with a dendritic/import-tree architecture:
   - `flake.nix` uses `mkFlake` + `import-tree ./nix`.
   - `nix/imports.nix` includes `inputs.flake-parts.flakeModules.modules`.
   - Outputs and host wiring happen through `config.flake.modules.*` and `config.flake.hosts.*`.
2. Existing repo conventions already discourage path-aggregator imports and favor one-file-one-responsibility modules. This matches import-tree and dendritic guidance.
3. Multi-target module dedup is already present in several modules (e.g., shared security and account defaults across nixos/darwin plus HM bootstrap), and can be strengthened by factoring common attrsets and reducing duplicated HM wiring blocks.
4. Host-level composition currently supports host-specific modules; introducing an explicit profile/role layer would improve readability as host count grows.
5. For cross-platform account/security modules, strongest consistent patterns are:
   - central account metadata/options,
   - per-target adapters for platform-specific paths/options,
   - HM modules referencing `osConfig` for platform-aware decisions,
   - one shared source of truth for username/keys/secrets.

## Issues/Bugs Encountered

- `ddgr` web search worked initially, then returned HTTP 202 responses for subsequent queries.
- Mitigation: used already discovered results plus direct documentation URLs and webfetch of known pages.

## Learning Points to Reuse

- Prefer official docs for normative semantics (flake-parts, HM manual) and community posts for structure tradeoffs (roles/profiles, core vs optional split).
- `flake-parts.modules` gives module class typing safety and is useful for preventing cross-class import mistakes in large multi-target trees.
- import-tree default `/_` ignore is useful for helper libraries to avoid accidental module imports.
- For reusable flake modules needing lexical-scope values, use `importApply` or option-bridging rather than relying on ambient scope.

## Output Intent

Deliver a concise but concrete report with:
- pros/cons by requested topic,
- source-linked patterns,
- actionable guidance mapped to this repo’s current structure.
