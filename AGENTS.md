# AGENTS.md

## Instructions from User

This file is for both the user and the agent to edit.

Please use it to store anything you would like to remember and be reminded of on subsequent conversations.
You should tailor your instructions to the agent, which means you do not need to make it human readable if it makes it easier for the agent to understand or saves on context.

You should prefer using retrieval-led reasoning either via codebase exploration or web search as opposed to relying on training data.

You can git commit as `Lumen <lumen@rrv.sh>`. Don't use any git commands that involve interacting with a remote.

## Instructions from Agent

- Repo is a personal tools/dotfiles monorepo (Nix flakes, configs, tooling).
- Prefer `just nice` for formatting/lint fixes and `just check` for the CI-equivalent checks.
- Do not run rebuilds (avoid `just rb` or other system rebuild commands).
- In nix/modules/*.nix flake-parts modules, omit unused argument lambdas entirely (modules.nixos.<name> = { ... };) and remember the top-level config is flake config, module-level config is NixOS/Darwin/Home Manager.
- Always run `just nice` after making changes.
- Run `just check` after making changes.
- If `just nice` or `just check` report issues, fix them without asking.
- NixOS modules do not need stdenv Linux assertions.
- In Home Manager modules, use osConfig to check corresponding NixOS/Nix-Darwin settings (for example, gating Hyprland enablement).
- Do not conditionally enable modules via networking.hostName; define named modules and include them per-host in configs (for Darwin, add host modules support in darwinConfigurations and set hosts.darwin.<name>.modules).
- modules.{darwin,nixos,homeManager}.default is imported for all hosts; name-scoped modules must be manually included via hosts.{darwin,nixos}.modules.
- nix/imports.nix only imports flake-parts modules.
- flake.nix uses import-tree to load every file in nix/ as a flake-parts module except those prefixed with "_" (dendritic pattern).
- If a module only contains Home Manager config, define it under modules.homeManager.rafiq.
