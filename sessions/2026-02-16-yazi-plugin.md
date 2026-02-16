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
- `main.lua` - Main plugin code (needs to be renamed to `init.lua`)
- `README.md` - Documentation
- `LICENSE` - License file

Plugin functionality: Copies the file path relative to the git root when pressing `c r` in yazi.

### 3. Nix Integration Research
Researched how to install Yazi plugins in Nix:
- Home Manager's `programs.yazi.plugins` option accepts an attribute set of plugins
- Each plugin must be a derivation that outputs files to `$out`
- The plugin entry point must be named `init.lua` (not `main.lua`)
- Keymaps are configured via `programs.yazi.keymap`

### 4. Implementation
Modified `nix/modules/yazi.nix` to:
1. Create a derivation for the plugin using `pkgs.fetchFromGitHub`
2. Rename `main.lua` to `init.lua` in the install phase
3. Add the plugin to `programs.yazi.plugins`
4. Configure the keymap (`c r`) to trigger the plugin

Key learnings:
- The plugin name in the `plugins` attribute set should NOT include the `.yazi` suffix (home-manager adds it automatically)
- Need to convert the nix-prefetch-url base32 hash to SRI format using `nix hash to-sri`
- **CRITICAL**: Use `mgr.prepend_keymap` not `manager.prepend_keymap` in the keymap configuration (home-manager uses abbreviated names)

### 5. Hash Retrieval
Got the correct hash for the plugin:
```bash
nix-prefetch-url --unpack https://github.com/aresler/path-from-root.yazi/archive/main.tar.gz
# Output: 1f7c9j30kxxw2xirfl59bkz8gxf5zgxyrlprl3f9mr8xh4vbwdfs

# Convert to SRI format:
nix hash to-sri --type sha256 1f7c9j30kxxw2xirfl59bkz8gxf5zgxyrlprl3f9mr8xh4vbwdfs
# Output: sha256-2jW+NoEd5ZrcoPnS7Pv7xfWH/lypUJdjF7z3CYZM7Lg=
```

### 6. Testing and Validation
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

## Cleanup
Removed the temporary worktree:
```bash
git worktree remove /var/folders/r1/kxzs8jw91h938l_8zt1n0s9c0000gn/T/tmp.lGX9yxix0D
```

## Bug Fix: Keymap Section Name

### Problem
Plugin installed but keybinding didn't work. Pressing `c r` had no effect.

### Root Cause
Used `manager.prepend_keymap` instead of `mgr.prepend_keymap` in the keymap configuration. Home-manager's yazi module uses abbreviated section names.

### Solution
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

### Testing
Created test scripts to verify configuration:
- `test_yazi_plugin.sh` - Basic plugin structure tests
- `test_yazi_final.sh` - Comprehensive verification

To test manually:
1. `cd` to a git repository
2. Run `yazi`
3. Hover over a file
4. Press `c` then `r` quickly (chord)
5. Check clipboard: `pbpaste`

## References
- https://yazi-rs.github.io/docs/plugins/overview
- https://github.com/nix-community/home-manager/blob/master/modules/programs/yazi.nix
- https://wiki.nixos.org/wiki/Yazi
- https://mynixos.com/home-manager/option/programs.yazi.keymap
