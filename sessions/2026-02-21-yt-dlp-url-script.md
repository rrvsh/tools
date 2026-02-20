# 2026-02-21 yt-dlp URL script

## Task

User asked for research before implementation: can dependencies be scoped to the command runtime instead of being installed broadly in `home.packages`.

## Exploration

- Reviewed current module: `nix/modules/aliases.nix`.
- Reviewed existing script pattern: `scripts/process.sh`.
- Searched web and docs for Nix script builders and runtime dependency handling.
- Verified `writeShellApplication` behavior from Nixpkgs docs and Noogle implementation.

## Findings

- `pkgs.writeShellApplication` supports `runtimeInputs` and injects them into `PATH` only for that script runtime.
- This allows adding a single generated package to `home.packages` while not adding each dependency as separate user-facing packages.
- For yt-dlp warnings, `ffmpeg` and a JS runtime (recommended: `deno`) can be provided via `runtimeInputs`.
- For current yt-dlp EJS guidance, runtime alone may not be enough in all packaging contexts; remote EJS components can be enabled via `--remote-components ejs:npm` (with deno/bun) or `ejs:github`.

## Implementation

- Implemented a standalone package in `nix/outputs/packages.nix` as `packages.yt-meta` using `pkgs.writeShellApplication`.
- Added runtime-scoped inputs: `yt-dlp`, `jq`, `ffmpeg`, `deno`.
- Script behavior:
  - Requires one argument (`yt-meta <url>`).
  - Runs `yt-dlp -J` with `--js-runtimes deno` and `--remote-components ejs:npm`.
  - Formats output as values-only CSV-like line: `title, uploader, dd/mm/yyyy`.

## Validation

- Executed: `nix run .#yt-meta -- "https://www.youtube.com/watch?v=9M7pKi-3o18"`.
- Observed output:
  - `How Do Cultures Evolve? - featuring Edward Burnett Tylor — Anthropology Theory #1, a partial perspective, 13/12/2017`
- Date conversion verified from source `upload_date=20171213` to `13/12/2017`.

## Repo checks

- Ran `just nice` and `just check`.
- Initial statix warning occurred due to repeated `packages.<name>` keys in `nix/outputs/packages.nix`.
- Fixed by refactoring to a single `packages = { ... };` attrset.
- Re-ran checks successfully.
