## Task
- Make obs home-manager module conditional for NixOS/Linux.

## Work Breakdown
- Reviewed existing obs and hyprland modules to understand home-manager patterns.
- Identified platform checks and module wrapping approach.
- Added Linux-only gating for the obs home-manager module.

## Decisions
- Use `lib.mkIf pkgs.stdenv.hostPlatform.isLinux` to gate the module on Linux/NixOS.
- Keep existing assertions and package wrapping intact.

## Learnings
- (pending)

## Bugs Encountered
- None.
