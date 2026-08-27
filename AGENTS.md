## Repo workflow

### Dev shell

Use the dev shell for repo commands. Tools such as `just` come from the dev shell, not the host.

If a command is missing, especially over SSH or in a fresh shell, run it through:

```sh
nix develop -c <command>
```

### Just commands

Prefer `just` recipes for repo tasks, run through the dev shell when needed:

```sh
nix develop -c just <recipe>
```

Use targeted recipes when possible:

- Format: `format`, or `format-gha`, `format-lua`, `format-nix`, `format-rs`
- Lint/fix: `lint`, or `lint-lua`, `lint-nix`, `lint-rs`
- Check: `check`, or `check-gha`, `check-lua`, `check-nix`, `check-rs`
- Test: `test`, or `test-nix`, `test-rs`

`lint-*`, `format`, and `rb` may edit files; inspect changes afterward.

### Rebuilds

Do not run rebuilds by default. Only run `just rb` if the user asks for it or explicitly allows rebuilds for the conversation.

Run rebuilds on the host whose configuration is affected. If editing from a different host, SSH to the affected host and run commands from that host's checkout.

For behavior-preserving refactors, compare the affected system derivation before and after the change when practical, then run `just rb` after approval.

`just rb` runs formatting/checks before rebuilding. If formatting changes files and the command fails, inspect/accept the formatting and rerun.

#### Multi-host rebuild validation

Only run multi-host rebuild validation if the user explicitly asks for it. Host remotes are configured for peer-to-peer pulls: on `alpha`, the `nemesis` remote points to `nemesis:~/Git/tools`; on `nemesis`, the `alpha` remote points to `alpha:~/Git/tools`. When validating a change on multiple hosts:

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

Applying a staged patch remotely before commit is okay for affected-host verification. After commit, prefer `git pull <current-host> <branch>` for host-to-host syncing; only hard reset when history was rewritten or a hard sync is explicitly needed:

```sh
git fetch <current-host> <branch>
git reset --hard FETCH_HEAD
nix develop -c just rb
```

## Commit conventions

Use atomic commits and conventional commits.

Do not commit or push until the user explicitly approves the commit up front. If the user says the commit is allowed, you may commit as instructed.

Commit syntax: `<type>(<concern>): <summary>`. The concern should be either a file or a concern, such as `AGENTS.md`, `flake.lock`, `nix`, `hyprland`, or `nemesis`.

Common commit types:

- `refactor`: behavior-preserving config/module extraction, reorganization, or cleanup.
- `feat`: new user-visible capability, service, package, or behavior.
- `fix`: bug fix or correction to existing behavior.
- `docs`: documentation-only changes.

## Nix config organization

The Nix config in `nix/` is organized as hosts, profiles, and atomic modules. Hosts compose profiles and host-specific modules; profiles compose reusable capabilities; modules define one concern each.

Nix flake inputs and source files must be tracked by git to be evaluated; remember to `git add` new files before evaluation/checks.

Style constraints:

- One concern per module: one capability, policy, service, tool, or feature.
- Prefer DRY shared policy; use small helpers/renderers when platform option shapes differ.
- Prefer concise Nix assignments when they remain clear.
- Use `inherit (<source>) <var>;` in `let/in` blocks when referencing variables.
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

For modules with home-manager configuration, use `home-manager.sharedModules` and wrap them in platform modules:

```nix
{
  config.flake.modules = {
    darwin.foo = {
      home-manager.sharedModules = [ cfg.modules.homeManager.foo ];
      # Darwin-only integration, e.g. homebrew.
    };
    nixos.foo = {
      home-manager.sharedModules = [ cfg.modules.homeManager.foo ];
      # NixOS-only integration, e.g. linux specific configuration.
    };
    homeManager.foo = {
      # ...
    };
  };
}
```

Profiles and hosts should import platform modules, not `homeManager` modules directly:

```nix
imports = with cfg.modules.nixos; [
  foo
];
```
