Always check for native modules or options first: Home Manager, NixOS, nix-darwin, or any other flake inputs in the project. If a native option exists, prefer enabling it. If not, look for another published Nix flake that provides the functionality. Only fall back to custom Nix code or package definitions when no existing module or flake solves the problem.

**Working Model (How Things Are Built)**
- **Flake wiring:** `flake.nix` uses `flake-parts` + `import-tree`; every file under `nix/` is a flake-part module. `flake.paths.root` points to repo root for path joins.
- **Public API lives in `nix/options/`:** Folder path mirrors option path. Options define schema + defaults; logic that doesn’t directly produce a flake output belongs here.
  - `options/hosts/darwin.nix` sets the default darwin module (hostPlatform aarch64-darwin, nix-homebrew + taps from inputs, rosetta builder, extra substituters, system.stateVersion=6).
  - `options/users/users.nix` defines user fields (`primary`, `email`, `pubkey`) and imports `_build_darwin_users.nix`.
  - `_build_darwin_users.nix` maps all declared users to system/home-manager users: uid = 501 + index, home `/Users/<name>`, authorizedKeys from `pubkey`, sudo NOPASSWD for admin group, HM users with stateVersion 25.11 and `useGlobalPkgs=true`.
  - `options/users/admin.nix` derives `users.admin` from the first `primary` user; sets `system.primaryUser` and `nix.settings.trusted-users`.
- **Builders produce outputs:** `builders/darwinConfigurations.nix` combines `cfg.modules.darwin.default` with per-host modules into `flake.darwinConfigurations`. `builders/allowedUnfreePackages.nix` turns `flake.allowedUnfreePackages` into `allowUnfreePredicate`.
- **Library + module pattern:** Files like `nix/rafiq.nix` declare data under `config.flake.users.users.*` and the matching modules under `config.flake.modules.{darwin,homeManager}.*`. Keep that split: data first, modules second.

**Existing Modules to Mimic**
- **Darwin user module shape (see `nix/rafiq.nix`):**
  - Sets shell to `pkgs.fish`, enables fish.
  - Adds overlays/substituters, activation script via `system.activationScripts.extraActivation.text`.
  - UI/system tweaks: scroll direction off, caps->Esc, pmset tweaks, Rosetta install.
  - Homebrew packages: `homebrew.brews = [ "docker" ]; homebrew.casks = [ "ghostty" ];`
- **Home Manager module shape (same file):**
  - Imports NVF and nix-index DB modules.
  - Symlinks config (`xdg.configFile."nvim/lua".source = root + /src/lua;`).
  - Packages include `gh` plus platform conditionals (`monitorcontrol`, `firefox-bin` on Darwin).
  - Shell aliases heavy on git helpers; prefer concise strings, heredocs only when necessary.
  - Programs: fish, ghostty (null on Darwin), yazi with overridden runtimeDeps, firefox (skip on Darwin), git with SSH signing, codex settings, carapace, zoxide, nix-index, mise, skim (defaultCommand rga), ripgrep-all, direnv + nix-direnv, starship with `concatStrings` for format, neovim-nightly overlay + plugins + LSP tools.
- **Lua style (`src/lua/rafiq.lua`):** Minimal plugin setup at top, options grouped, keymaps with descriptions, LSP setup with per-server config; stylua-friendly 2-space indents.

**Conventions to Follow**
- Nix: 2-space indent; reference full paths (e.g., `config.flake.*`); keep lists/attr sets sorted; brief comments only where logic isn’t obvious.
- Place common defaults in `options/.../default`-like modules; per-entity specifics in their own file (e.g., `rafiq.nix`, `alpha.nix`).
- Prefer native modules/inputs (Home Manager, nix-darwin, existing flakes) before writing custom derivations.
- Dev shell/tools: `nix/shell.nix` provides bacon, just, sops, ssh-to-age, deadnix, statix, treefmt, stylua, gh, zizmor, etc.; use `just nice` (format+lint) or `just check` (CI-equivalent).
- CI expectations: `nix develop -c just check` is the check workflow; doc workflow requires Markdown changes with code.
- Secrets: SOPS with age key (`.sops.yaml`); never commit decrypted files.

**Structural Cues When Adding**
- Add a new option → create matching file under `nix/options/...`; expose schema via `mkOption`.
- Add a new module/output → prefer `builders/` if it directly feeds a flake output; otherwise put supporting logic in `options/`.
- New user/host → define data under `nix/<name>.nix` and rely on `_build_darwin_users.nix`/`darwinConfigurations.nix` to wire it.

**Additional Conventions**
- Scope config narrowly: prefer per-user settings under `flake.users.users.<name>`; use per-host settings under `flake.hosts.darwin.<name>` only when machine-specific.
- Keep logic in matching module paths so user/host concerns stay separated and wiring remains clear.
- Aim for stateless, declarative designs; when full statelessness is impossible, find a way to change the problem or solution to allow a stateless implementation.
- Keep scripts in `src/` (e.g., `src/sh/...`) and keep Nix files focused on Nix expressions; avoid inlining long shell snippets.
- When pulling scripts into activation, use store-backed references (e.g., `system.activationScripts.source`) or similar so runtime doesn’t depend on the checkout path.
- As the agent, suggest tooling/process upgrades (shfmt, shellcheck, bats, CI hooks) and propose adding revisions to `AGENTS.md` when gaps appear in your understanding or knowledge.
- Mark internal-only options with `internal = true; visible = false;` and explain why they shouldn’t be user-facing (e.g., managed universes should not shrink).
- Write docs/tickets in the first person; audience is a single macOS maintainer.
- When working in any directory, skim its README.md (and nested readmes) first; treat them as local policy that can override general guidance.
