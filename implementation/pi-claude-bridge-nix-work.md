# pi-claude-bridge-nix implementation

## Summary

Created and published `rrvsh/pi-claude-bridge-nix`, a pinned Nix flake packaging `@vanillagreen/pi-claude-bridge` 1.5.0 from `vanillagreencom/vstack` source. The tools repo now consumes that flake and configures Pi on the Darwin `claude-code` module to load the Nix-built bridge from the store instead of the npm registry spec.

## Upstream pin

- Source root: `pi-extensions/pi-claude-bridge`
- Lockfile source: upstream subdirectory `package-lock.json`
- Version: `1.5.0`
- Upstream rev/gitHead: `d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd`
- Source hash: `sha256-VmGea5gTfD3KgkX6/nongGVcRwM96uSmLKq0RxeL0zY=`
- npm deps hash: `sha256-Mcr6n1SgVoN+XiI+sArROnUmkGN9soaWtPRFCA4LjY4=`

## Bridge repo

Changed files:

- `/home/rafiq/1_repos/pi-claude-bridge-nix/flake.nix`
- `/home/rafiq/1_repos/pi-claude-bridge-nix/flake.lock`
- `/home/rafiq/1_repos/pi-claude-bridge-nix/VERSION.json`
- `/home/rafiq/1_repos/pi-claude-bridge-nix/nix/pi-claude-bridge.nix`
- `/home/rafiq/1_repos/pi-claude-bridge-nix/nix/update.nix`
- `/home/rafiq/1_repos/pi-claude-bridge-nix/patches/fix-multi-tool-results.patch`
- `/home/rafiq/1_repos/pi-claude-bridge-nix/.github/workflows/build.yml`
- `/home/rafiq/1_repos/pi-claude-bridge-nix/.github/workflows/update.yml`

The package builds from source with Node 22, runs upstream typecheck and `tests/unit-import.mjs`, applies a local patch adding a focused multi-tool interleaving regression test, and verifies install output metadata for Pi extension loading.

Committed and pushed:

- `f69bd3a feat(nix): package pi claude bridge`
- Remote: `git@github.com:rrvsh/pi-claude-bridge-nix.git`

## Tools repo

Changed files:

- `/home/rafiq/1_repos/tools/flake.nix`
- `/home/rafiq/1_repos/tools/flake.lock`
- `/home/rafiq/1_repos/tools/nix/modules/claude-code.nix`
- `/home/rafiq/1_repos/tools/progress.md`
- `/home/rafiq/1_repos/tools/implementation/pi-claude-bridge-nix-work.md`

`claude-code.nix` now uses:

- `inputs.pi-claude-bridge.packages.${system}.pi-claude-bridge`
- `bridge.passthru.packagePath` as an absolute Nix store package directory

This is consistent with Pi package docs indicating absolute local package directories are accepted in settings.

## Validation run

Passed:

- `cd /home/rafiq/1_repos/pi-claude-bridge-nix && nix build --print-build-logs .#pi-claude-bridge`
- `cd /home/rafiq/1_repos/pi-claude-bridge-nix && nix flake show --all-systems`
- `cd /home/rafiq/1_repos/pi-claude-bridge-nix && nix run .#update`
- `cd /home/rafiq/1_repos/pi-claude-bridge-nix && git diff --check`
- `cd /home/rafiq/1_repos/tools && nix flake lock --update-input pi-claude-bridge`
- `cd /home/rafiq/1_repos/tools && nix develop -c just format-nix`
- `cd /home/rafiq/1_repos/tools && nix develop -c just check-nix`
- `cd /home/rafiq/1_repos/tools && nix develop -c just test-nix`
- `cd /home/rafiq/1_repos/tools && nix eval --json .#darwinConfigurations.auto.config.home-manager.users.binmohm.programs.pi-coding-agent.settings.packages`
- `cd /home/rafiq/1_repos/tools && nix build .#darwinConfigurations.auto.config.system.build.toplevel --dry-run`

Key eval output:

```json
["npm:pi-mcp-adapter","npm:pi-subagents","npm:pi-web-access","npm:pi-hermes-memory","/nix/store/sdl9s2naq0201887m4iffpyridjkfnsl-pi-claude-bridge-1.5.0/lib/node_modules/@vanillagreen/pi-claude-bridge"]
```

The bridge package unit test output included the added regression:

- `interleaved Pi user text is held until all parallel tool results are adjacent`
- `tests 28`, `pass 28`, `fail 0`

## Tools commit/push

Committed locally:

- `feat(claude-code): use nix packaged pi bridge` (current branch HEAD)

Push status:

- `git push origin gtnh-server` was rejected because the remote branch is ahead/non-fast-forward.
- Pushed the same commit to `origin/pi-claude-bridge-nix-integration` for transfer/review without forcing or rewriting remote history.

## Deployment status

Not deployed from this session. Current host is `nemesis`, while the affected host is Darwin `auto`. The dry-run for `auto` succeeded and showed the Darwin bridge derivation would be built. `ssh -o BatchMode=yes auto ...` failed with `Permission denied (publickey)`, so I could not pull/rebuild on `auto`. Deploy by pulling `origin/pi-claude-bridge-nix-integration` on `auto` and running `nix develop -c just rb` there.

## Rollback

Revert the tools integration commit or restore `programs.pi-coding-agent.settings.packages = [ "npm:@vanillagreen/pi-claude-bridge" ];`, remove/ignore the new `pi-claude-bridge` flake input, run `nix develop -c just check-nix`, and rebuild `auto`.
