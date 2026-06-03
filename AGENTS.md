## Repo workflow

Use the dev shell for repo commands. Tools such as `just` come from the dev shell, not the host.

If a command is missing, especially over SSH or in a fresh shell, run it through:

```sh
nix develop -c <command>
```

Do not run rebuilds by default. Only run `just rb` if the user asks for it or explicitly allows rebuilds for the conversation.

`just rb` runs formatting/checks before rebuilding. If formatting changes files and the command fails, inspect/accept the formatting and rerun.

Only run multi-host rebuild validation if the user explicitly asks for it. Host remotes are configured for peer-to-peer pulls: on `alpha`, the `nemesis` remote points to `nemesis:~/1_repos/tools`; on `nemesis`, the `alpha` remote points to `alpha:~/1_repos/tools`. When validating a change on multiple hosts:

1. Rebuild the current host first:

```sh
nix develop -c just rb
```

2. If it succeeds, commit the change.
3. SSH into the other host, confirm the checked-out branch, then pull the same branch from the current host remote:

```sh
git branch --show-current
git pull <current-host> <branch>
nix develop -c just rb
```

Do not pull a different branch into the other host's current branch. For example, if the other host is on `prime`, do not pull `atomic` into it unless explicitly intended.

If history was rewritten and a hard sync is needed:

```sh
git fetch <current-host> <branch>
git reset --hard FETCH_HEAD
nix develop -c just rb
```

## Commit conventions

Use atomic commits and conventional commits.

Commit syntax: `<type>(<concern>): <summary>`. The concern should be either a file or a concern, such as `AGENTS.md`, `flake.lock`, `nix`, `hyprland`, or `nemesis`.

Common commit types:

- `refactor`: behavior-preserving config/module extraction, reorganization, or cleanup.
- `feat`: new user-visible capability, service, package, or behavior.
- `fix`: bug fix or correction to existing behavior.
- `docs`: documentation-only changes.

## Nix config organization

The Nix config in `nix/` is organized as atomic modules in `nix/modules/`.

Nix flake inputs and source files must be tracked by git to be evaluated; remember to `git add` new files before evaluation/checks.

Module constraints:

- One concern per module: one capability, policy, service, tool, or feature.
- Hosts explicitly import the modules they use.
- Host-specific values stay in host files: hostname, architecture, disks, bootloader, hardware, secrets wiring, and state versions.
- Do deep, exhaustive research when writing or changing a module to ensure available options, defaults, behavior, and NixOS/Darwin/Home Manager differences are understood and the config is ideal.
- Prefer DRY shared policy; use small helpers/renderers when platform option shapes differ.
- Prefer concise Nix assignments when they remain clear.
- Use `inherit (cfg.paths) root;` in module `let` blocks when referencing the repo root.
- Avoid blank lines unless they improve semantic grouping.

When the same concern has different Darwin, NixOS, or Home Manager implementations, keep them in one module file so the concern is centralized for reference and changes:

```nix
{
  config.flake.modules.darwin.foo = { ... };
  config.flake.modules.nixos.foo = { ... };
  config.flake.modules.homeManager.foo = { ... };
}
```

Single-platform concerns should only export that platform.

Good examples: `nix-settings`, `passwordless-sudo`, `ssh-config`.
