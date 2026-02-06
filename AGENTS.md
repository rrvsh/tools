# AGENTS.md

## Instructions from User

This file is for both the user and the agent to edit.
Please use it to store anything you would like to remember and be reminded of on subsequent conversations.
You should tailor your instructions to the agent, which means you do not need to make it human readable.

### Things to remember

- Always use retrieval-led reasoning either via codebase exploration or web search. Never rely on training data.
- You can git commit as `Lumen <lumen@rrv.sh>` using `--author "Lumen <lumen@rrvsh>"` so commits are signed.
    - Don't use any git commands that involve interacting with a remote unless the user explicitly asks you to.
- `Justfile` contains commands for working with the repo like formatting and linting.
    - Don't run `just rb` or apply NixOS/nix-darwin configurations unless the user explicitly asks you to.
    - Ensure `just nice` and `just check` fully pass after making changes.
        - Do not ask if you should fix them, just fix it.
- `flake.nix` imports all files (without an underscore prefix e.g. `_example.nix`) in `nix/` as `flake-parts` modules.
    - `config.flake.paths.root` provides the path to the repository root for referencing directories in the repo.
    - You should never import Nix modules by using paths. Only use `config.flake.modules.{darwin,nixos}`.
    - The top level arguments for each file provide `config` (the flake config, including the flake outputs) and `lib` (from nixpkgs).
        - Project convention is to declare `{config,...}: let cfg = config.flake; in {...}` to avoid conflicts with the module-level `config`.
        - You never need to include empty lambda arguments like `{ ... }:` or `{ _ }:`.
    - `nix/outputs` consumes the configuration from `nix/configs` and `nix/modules` to build flake outputs.
        - `{darwin,nixos}Configurations.nix` builds `nix-darwin` and NixOS configurations.
            - `hosts.{darwin,nixos}.<name>.modules` is exposed as an option for importing modules for that host.
            - Nix configuration under `modules.{darwin,nixos}.default` is imported for all hosts of that class (NixOS/Darwin).
        - `packages.nix` builds the binary and container image for `rs/site`.
        - `devShells.nix` builds shells for local development and CI.
    - `nix/configs` contains host specific config under the key `config.flake.hosts.{darwin,nixos}.<hostname>.modules = []`.
        - Adding config specific to a host that is not used for any other should be added under the above key.
        - Adding modules to a host that is not under the `modules.{darwin,nixos}.default` key should be done by including the module under the above key.
            - e.g. `nix/configs/nemesis.nix` imports `cfg.modules.nixos.{steam,nvidia,hyprland}` as it is a desktop.
    - `nix/modules` contains NixOS, Home Manager, and nix-darwin modules.
        - One file = one responsibility, e.g. `ssh.nix`, `git.nix`, etc.
            - One file can contain multiple modules e.g. for NixOS, nix-darwin, and home-manager.
        - Modules should contain assertions to ensure dependencies are met.
            - NixOS modules do not need stdenv Linux assertions.
        - When adding SOPS secrets, define `sops.secrets.<name>.sopsFile = root + /sops/<secret filename>.yaml` and reference config.sops.secrets.<name>.path.
            - Refer to `nix/modules/build_users.nix`
        - Modules can receive arguments:
            - `pkgs` is the nixpkgs set for the host the module is being imported into.
            - `config` is the home-manager, nix-darwin, or nixos configuration the module is being imported into.
            - `osConfig` (only for home-manager modules) contains the nix-darwin or nixos configuration of the host.
        - To include configuration for all hosts:
            - NixOS/Darwin modules: Define it under `cfg.modules.{nixos,darwin}.default`.
            - Home Manager modules: Define it under `cfg.modules.homeManager.rafiq`.
        - To include configuration that can be conditionally imported:
            - NixOS/Darwin modules: Define it under `cfg.modules.{nixos,darwin}.<name>` and import it in `nix/configs`.

## Instructions from Agent

