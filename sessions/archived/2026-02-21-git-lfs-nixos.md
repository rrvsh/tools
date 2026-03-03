## Task
- Investigate why `programs.git.lfs.enable` breaks only on NixOS, fix the issue, and document the process.

## Work Log
- Started by reviewing repo Nix modules and host configs to understand home-manager integration and where git/lfs, starship, and zoxide are configured.
- Reproduced on `nemesis` via `just rb` and captured `home-manager-rafiq` logs.
- Identified activation failure: `nix profile` conflict on `git-lfs` (existing `nix profile` install collided with home-manager `home-manager-path`).
- Removed user `nix profile` entry (`nix profile remove git-lfs`) to unblock activation.
- Added `home-manager.useUserPackages = true;` to NixOS and nix-darwin config to avoid `nix profile` installs during activation.
- Re-applied config on `nemesis` using `nh os switch .` and re-ran `just rb` (via direnv) successfully.

## Notes
- Home-manager is integrated for both NixOS and nix-darwin via `nix/modules/build_users.nix`.
- `programs.starship` and `programs.zoxide` are home-manager modules, so missing binaries suggest a profile activation/linking issue, not a direct git-lfs install failure.
- Home-manager activation failed at `installPackages` because `nix profile` already had `git-lfs` with conflicting file priority.
- Enabling `home-manager.useUserPackages` switches to system-managed per-user packages and avoids `nix profile` conflicts.
- `just rb` run with `nix develop` failed due to `nixfmt` attempts in read-only Nix store; rerunning via `direnv exec` resolved it.
