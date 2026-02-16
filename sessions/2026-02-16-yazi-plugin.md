# Session: Installing path-from-root.yazi Plugin

Date: 2026-02-16

## Objective
Install the https://github.com/aresler/path-from-root.yazi plugin into the Nix configuration at `nix/modules/yazi.nix`.

## Process

### 1. Git Worktree Setup
Created a temporary git worktree to work in isolation:
```bash
mktemp -d
git worktree add /var/folders/r1/kxzs8jw91h938l_8zt1n0s9c0000gn/T/tmp.lGX9yxix0D
```

### 2. Plugin Repository Exploration
Cloned the plugin repository to understand its structure:
```bash
git clone --depth 1 https://github.com/aresler/path-from-root.yazi.git /tmp/yazi-plugin
```

The plugin structure:
- `main.lua` - Main plugin code (**this is the correct entry point**)
- `README.md` - Documentation
- `LICENSE` - License file

Plugin functionality: Copies the file path relative to the git root when pressing `c r` in yazi.

**Important**: Yazi plugins use `main.lua` as the entry point, NOT `init.lua`. The `init.lua` file is for the user's main Yazi configuration file (at `~/.config/yazi/init.lua`), not for individual plugins.

### 3. Nix Integration Research
Researched how to install Yazi plugins in Nix:
- Home Manager's `programs.yazi.plugins` option accepts an attribute set of plugins
- Each plugin must be a derivation that outputs files to `$out`
- The plugin entry point must be named `main.lua` (NOT `init.lua`)
- Keymaps are configured via `programs.yazi.keymap`
- Use `mgr.prepend_keymap` not `manager.prepend_keymap` (home-manager uses abbreviated names)

### 4. Implementation
Modified `nix/modules/yazi.nix` to:
1. Add the plugin repository as a flake input (`path-from-root-yazi`)
2. Create a derivation for the plugin using the flake input
3. Keep `main.lua` as-is (Yazi expects this filename)
4. Add the plugin to `programs.yazi.plugins`
5. Configure the keymap (`c r`) to trigger the plugin
6. Add home activation script to test the plugin on rebuild

Key learnings:
- The plugin name in the `plugins` attribute set should NOT include the `.yazi` suffix (home-manager adds it automatically)
- Yazi plugins use `main.lua`, not `init.lua`
- Use `config.flake.paths.root` to reference files in the flake (not relative paths like `../../`)
- **Project convention**: Use `cfg = config.flake;` in a let-binding, then access paths via `cfg.paths.root` (shorter and more idiomatic)

### 5. Flake Input Setup
Added the plugin as a flake input in `flake.nix`:
```nix
path-from-root-yazi = {
  url = "github:aresler/path-from-root.yazi";
  flake = false;
};
```

Using `flake = false` because the repository is not a Nix flake, just a plain git repo.

### 6. Testing and Validation
Created `scripts/test-yazi-plugin.sh` to verify the plugin installation:
- Checks plugin directory exists
- Verifies `main.lua` is present (not `init.lua`)
- Validates keymap configuration
- Tests git commands the plugin uses

Added home activation to run the test automatically:
```nix
home.activation.test-yazi-plugin = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${test-yazi-plugin}/bin/test-yazi-plugin || true
'';
```

Ran all relevant checks:
```bash
just check
```

All checks passed:
- zizmor (GitHub Actions security) - passed
- stylua (Lua formatting) - passed
- treefmt (Nix formatting) - passed
- statix (Nix linting) - passed
- deadnix (dead Nix code) - passed
- cargo clippy (Rust linting) - passed
- nix flake check --all-systems - passed
- cargo test - passed

## Final Configuration
The plugin is now installed and configured with:
- Keybinding: `c r` (press c, then r)
- Function: Copies the path of the hovered file relative to git root
- Requirement: Target file must be in a git repository
- Test script: `scripts/test-yazi-plugin.sh` (runs on home activation)

## Bug Fixes

### Bug 1: Wrong Keymap Section Name

#### Problem
Plugin installed but keybinding didn't work. Pressing `c r` had no effect.

#### Root Cause
Used `manager.prepend_keymap` instead of `mgr.prepend_keymap` in the keymap configuration. Home-manager's yazi module uses abbreviated section names.

#### Solution
Changed:
```nix
keymap = {
  manager.prepend_keymap = [  # WRONG
```

To:
```nix
keymap = {
  mgr.prepend_keymap = [  # CORRECT
```

### Bug 2: Wrong Entry Point Filename

#### Problem
Got error: "Plugin load failed, failed to load plugin from '/Users/rafiq/.config/yazi/plugins/path-from-root.yazi/main.lua'"

#### Root Cause
Initially renamed `main.lua` to `init.lua` in the derivation, but Yazi expects `main.lua` for plugins. The `init.lua` filename is only for the user's main Yazi configuration, not for individual plugins.

#### Solution
Keep `main.lua` as-is in the derivation:
```nix
installPhase = ''
  mkdir -p $out
  cp -r . $out/
  # Keep main.lua as is - that's what yazi expects
'';
```

### Bug 3: Wrong File Path Reference

#### Problem
Used relative path `../../scripts/test-yazi-plugin.sh` which doesn't work correctly in all contexts.

#### Root Cause
Relative paths can break depending on how the module is evaluated.

#### Solution
Use `config.flake.paths.root` to reference the flake root, following project convention:
```nix
let
  cfg = config.flake;
in
  test-yazi-plugin = pkgs.writeShellScriptBin "test-yazi-plugin" (
    lib.fileContents (cfg.paths.root + "/scripts/test-yazi-plugin.sh")
  );
```

## Testing

### Automated Testing
The test script runs automatically on home activation and verifies:
1. Plugin directory structure
2. `main.lua` exists (critical!)
3. Keymap configuration is correct
4. Yazi CLI is available
5. Git commands work properly

### Manual Testing
To test manually:
1. `cd` to a git repository
2. Run `yazi`
3. Hover over a file
4. Press `c` then `r` quickly (chord/key sequence)
5. Check clipboard: `pbpaste`

## Cleanup
Removed the temporary worktree:
```bash
git worktree remove /var/folders/r1/kxzs8jw91h938l_8zt1n0s9c0000gn/T/tmp.lGX9yxix0D
```

## References
- https://yazi-rs.github.io/docs/plugins/overview
- https://github.com/nix-community/home-manager/blob/master/modules/programs/yazi.nix
- https://wiki.nixos.org/wiki/Yazi
- https://mynixos.com/home-manager/option/programs.yazi.keymap
- https://yazi-rs.github.io/docs/configuration/keymap
