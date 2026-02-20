# 2026-02-20 - Neovim server + client editor flow

## Goal

Configure Home Manager so Neovim runs as a background server and `$EDITOR` opens a client UI attached to that server.

## Changes made

- Updated `nix/modules/neovim.nix` to add a Linux user service `systemd.user.services.nvim-server`.
- Service runs Neovim headless with a fixed listen address: `$XDG_RUNTIME_DIR/nvim/server.pipe`.
- Added `ExecStartPre` to create runtime socket directory.
- Added a wrapper command `nvim-client` via `writeShellScriptBin`.
  - Uses `NVIM_SERVER` (defaulting to `$XDG_RUNTIME_DIR/nvim/server.pipe`).
  - Attempts to start `nvim-server.service` if socket is missing.
  - Waits briefly for socket creation.
  - Opens remote UI with `--server ... --remote-ui`, falls back to normal `nvim` if server is unavailable.
- Disabled `programs.neovim.defaultEditor` and set:
  - `home.sessionVariables.EDITOR = "nvim-client"`
  - `home.sessionVariables.VISUAL = "nvim-client"`
- Added `nvim-client` to `home.packages`.

## Decisions

- Kept Neovim package/config source as `programs.neovim` and referenced `config.programs.neovim.finalPackage` in both service and wrapper so server/client always use the same configured Neovim binary.
- Kept service Linux-only with `lib.mkIf pkgs.stdenv.isLinux` because this uses `systemd.user.services`.

## Notes / gotchas

- `--remote-ui` creates a fully interactive client UI attached to the server process, so registers and state are shared.
- Fallback to plain `nvim` in wrapper prevents hard failure if service/socket is unavailable.
