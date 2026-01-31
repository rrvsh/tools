This file is for both the user and the agent to edit.

Please use it to store anything you would like to remember and be reminded of on subsequent conversations.

## repo overview

- this is rafiq's personal tools/infra repo (nix flake with flake-parts + import-tree)
- primary areas:
  - `nix/` flake modules/configs
  - `nvim/` neovim config
  - `rs/` rust workspace (currently `site` web server with axum + askama, edition 2024)
  - `tf/` terraform/opentofu for aws (ap-southeast-1, s3 backend bucket `rrvsh-tfstate-dev`)
  - `docs/` runbook + cheatsheet

## common commands (Justfile)

- `just nice` format + auto-fix (treefmt, statix fix, deadnix --edit, cargo fmt, tofu fmt, stylua)
- `just check` full ci-style check (zizmor, stylua --check, treefmt --ci, statix check, deadnix, cargo clippy/fmt, tests)
- `just rb` run `nice` + `check`, then `nh darwin switch .`
- `just watch-site` / `just watch-clippy` use bacon for the rust site
- `just run-docker` builds the nix `site` image and runs a container
- `just setup` copies `.env`, ensures aws creds configured, starts colima

## guardrails

- do not run system rebuilds (for example `just rb`, `nh darwin switch`, or `darwin-rebuild`) unless explicitly asked
