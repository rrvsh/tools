{ config, inputs, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.nix-index-comma ];
  };
in
{
  config.flake.modules = {
    darwin.nix-index-comma = osModule;
    nixos.nix-index-comma = osModule;
    homeManager.nix-index-comma = {
      imports = [ inputs.nix-index-database.homeModules.nix-index ];
      programs = {
        nix-index.enable = true;
        nix-index-database.comma.enable = true;
      };
      home.file.".pi/agent/skills/comma/SKILL.md".text = ''
        ---
        name: comma
        description: Use comma (`,`) to run missing dependencies from nixpkgs without preinstalling. Prefer this whenever a command is missing; use `, python3` for Python tasks.
        ---

        # Comma (system skill)

        Always prefer comma for missing tools.

        ## First check

        ```bash
        , --help
        ```

        ## Core usage

        ```bash
        , <command> [args...]
        , jq --version
        , rg --version
        , python3 --version
        ```

        ## Python requirement

        If Python is needed, run through comma:

        ```bash
        , python3 script.py
        ```

        ## nix-index-database (GitHub)

        Repo: https://github.com/nix-community/nix-index-database

        Use this for a prebuilt, frequently updated nix-index DB and optional comma wrapping in NixOS/Home Manager/nix-darwin.

        Useful notes:
        - Weekly updated nix-index DB for nixos-unstable
        - Provides modules that can enable wrapped `nix-index` and optional wrapped `comma`
        - Requires Nix >= 2.18

        Home Manager / NixOS module option to enable comma wrapper:

        ```nix
        { programs.nix-index-database.comma.enable = true; }
        ```
      '';
    };
  };
}
