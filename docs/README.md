## current state

`nodes.nixos.veil` has nginx setup and the `rrv.sh` website.
`manifest` has externals and proxies skeleton impl set up.

## directory structure

- `docs/` should contain:
    - README.md -> instructions and information
    - runbook.md -> commands and procedures
- `ops/` should contain IaC:
    - `nix/` contains Nix code that is consumed by `flake.nix` in the root directory
    - `sops/` contains sops encrypted secrets with age

## dev setup

with `direnv`, run `direnv allow` and all dependencies will be in your shell.

run:

- `just nice` to format and lint
- `just check` to test

## architecture

`ops/nix/manifest/manifest.nix` describes the overview of the IaC. the rest construct the system configs.
