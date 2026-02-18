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

## Yazi & Home-Manager Patterns

- **Yazi plugins**:
    - **entry point**: Plugins use `main.lua`, NOT `init.lua` (which is only for the main config)
    - **Home-manager abbreviated keymap names**: Use `mgr.prepend_keymap` not `manager.prepend_keymap` (home-manager uses abbreviated section names)
- **Plugin naming convention**: Don't include `.yazi` suffix in plugin names (home-manager adds it automatically)
- **Flake paths**: Use `config.flake.paths.root` to reference flake files, not relative paths like `../../scripts/`
- **Non-flake inputs**: Use `flake = false` for plain git repos in flake inputs
- **Idiomatic pattern**: Use `let cfg = config.flake;` let-binding, then access via `cfg.paths.root`

## Neovim + Flake Patterns

- Add Neovim plugins through flake inputs and module wiring, not ad-hoc local paths.
    - For plain git repos, set `flake = false` in `flake.nix` and update `flake.lock`.
- Keep plugin and runtime dependency wiring in `nix/modules/neovim.nix`.
    - Add required binaries via Neovim extra packages (example: `unzip` for `epub.nvim`).
- Prefer upstream flake outputs when available (example: `packages.<system>.fff-nvim`) to avoid custom build glue.
- Initialize plugins in Lua with minimal `require("<plugin>").setup(...)` unless custom behavior is required.
