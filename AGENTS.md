## Repo workflow

Use the dev shell for repo commands. Tools such as `just` come from the dev shell, not the host.

If a command is missing, especially over SSH or in a fresh shell, run it through:

```sh
nix develop -c <command>
```

Do not run rebuilds by default. Only run `just rb` if the user asks for it or explicitly allows rebuilds for the conversation.

`just rb` runs formatting/checks before rebuilding. If formatting changes files and the command fails, inspect/accept the formatting and rerun.

## Commit conventions

Use atomic commits and conventional commits.

TODO: Improve commit guidance as the agent gets conventions wrong.

## Multi-host workflow

Hosts can fetch from each other using configured host remotes.

Prefer normal pulls when history has not been rewritten:

```sh
git pull <host> <branch>
```

If history was rewritten and a hard sync is needed:

```sh
git fetch <host> <branch>
git reset --hard FETCH_HEAD
```

## Nix config organization

The Nix config in `nix/` is organized as atomic modules in `nix/modules/`.

Module constraints:

- One concern per module: one capability, policy, service, tool, or feature.
- Hosts explicitly import the modules they use.
- Host-specific values stay in host files: hostname, architecture, disks, bootloader, hardware, secrets wiring, and state versions.
- Do deep, exhaustive research when writing or changing a module to ensure available options, defaults, behavior, and NixOS/Darwin/Home Manager differences are understood and the config is ideal.
- Prefer DRY shared policy; use small helpers/renderers when platform option shapes differ.

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
