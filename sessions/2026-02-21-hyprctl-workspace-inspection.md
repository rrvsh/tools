## Task

Experiment with the `hyprctl` CLI and discover as much as possible about the current Hyprland workspace state.

## Plan

1. Enumerate available `hyprctl` commands.
2. Run broad read-only inspection commands for compositor, monitor, workspace, client, input, and config state.
3. Summarize findings focused on the active/current workspace.

## Notes

- Enumerated command surface with `hyprctl --help`.
- Confirmed single running Hyprland instance on socket `wayland-1`.
- Captured version/build metadata: Hyprland `0.53.0` (Nix build, dirty tree), commit `0de216e...`.
- Captured monitor topology:
  - One active monitor: `HDMI-A-1` (`3840x2160@160Hz`, scale `2.00`), focused, DPMS on.
  - No inactive/extra outputs from `monitors all`.
- Captured workspace state:
  - Existing workspaces: `1`, `2`, `3`.
  - Active workspace: `3` on monitor `HDMI-A-1`, `2` windows, no fullscreen.
  - Workspace window counts: `1 -> 2`, `2 -> 3`, `3 -> 2`.
- Captured client inventory:
  - 7 mapped windows total (Ghostty + Firefox), all Wayland (`xwayland: false`).
  - Active window: Ghostty (`address 0x55a549a62600`) on workspace `3`, tiled at `961,1`, size `958x1078`.
  - Workspace 3 appears split into two equal tiled columns (two Ghostty windows).
- Captured input devices:
  - 3 pointer-class devices listed under mice.
  - 8 keyboards listed; `zmk-project-urchin-keyboard` is marked `main: true`.
- Captured config/runtime surfaces:
  - Layout engines available: `dwindle`, `master`; configured layout: `dwindle`.
  - Gaps in/out are `0 0 0 0`; border size `1`; rounding `0`; active/inactive opacity `1.0`.
  - `input:follow_mouse = 1`.
  - Workspace rules: none.
  - Global shortcuts registry: empty.
  - Plugins loaded: none.
  - Config errors: none.
  - Layers: no registered background/bottom/top/overlay surfaces.
- Ran `hyprctl rollinglog` snapshot and observed active libinput mouse wheel + DRM cursor buffer debug activity.
- Queried auxiliary command help:
  - `plugin`: `load|unload|list`
  - `hyprpaper`: dynamic `wallpaper` requests
  - `hyprsunset`: `temperature|identity|gamma`

## Follow-up: current workspace windows

- Re-queried `activeworkspace`, `activewindow`, and full `clients` list.
- Active workspace remains `3` with exactly `2` windows.
- Window A (focused): address `0x55a549a62600`, title `OC | Hyprctl CLI exploration of current wo...`, class `com.mitchellh.ghostty`, geometry `961,1 958x1078`, `focusHistoryID: 0`.
- Window B (sibling): address `0x55a549a6cb40`, title `v ~/1/tools`, class `com.mitchellh.ghostty`, geometry `1,1 958x1078`, `focusHistoryID: 1`.
- Both windows share `pid 2112`, indicating they are two Wayland toplevels from the same Ghostty process.
- Shared state for both: mapped/visible, tiled (`floating: false`), not fullscreen, not pinned, ungrouped, no tags, no idle inhibit, no xdg metadata.
- Attempted `hyprctl decorations <regex>` for these windows returned `none`, consistent with no extra decoration objects currently reported by Hyprland.

## Follow-up: data needed for 1/3 vs 2/3 split

- Goal interpretation: keep two tiled windows on workspace `3`, left window at one-third width, right window at two-thirds width, full height.
- Required state signals obtainable via `hyprctl`:
  - Active workspace identity and window count (`activeworkspace`) to ensure exactly two windows are targeted.
  - Window identities and left/right ordering (`clients` by workspace and `at.x`) to know which address should become 1/3 side.
  - Usable geometry baseline (`clients` current `at`/`size`, and optionally `monitors`) to validate post-change dimensions.
  - Layout engine in use (`getoption general:layout`) to choose ratio control path.
  - Layout-specific knobs (`getoption master:mfact`, `getoption master:orientation`, and dwindle options) to know whether ratio should be set via master factor or split ratio.
  - Gap/border context (`getoption general:gaps_in`, `general:gaps_out`, `general:border_size`) for exact pixel expectation vs approximate ratio.
- Current relevant values gathered:
  - Layout: `dwindle`.
  - Workspace `3`: 2 windows.
  - Left window (x=1): `0x55a549a6cb40` (`v ~/1/tools`) width `958`.
  - Right window (x=961): `0x55a549a62600` (`OC | ...`) width `958`.
  - Gaps in/out: all zero; border size: `1`.
  - Master defaults (if switching strategy): `mfact=0.55`, `orientation=left`, `new_status=slave`.

## Implementation: automated 1/3 vs 2/3 splitter

- Added new Rust crate: `rs/hyprctl-split` and included it in `rs/Cargo.toml` workspace members.
- Crate behavior:
  - Uses only `hyprctl` CLI for runtime data gathering and applying changes.
  - Reads active workspace, active monitor, layout, gaps, border size, and mapped/visible client windows on the active workspace.
  - Sorts workspace windows by `x` position and treats leftmost/rightmost as split targets.
  - Computes 1/3 : 2/3 widths from current combined window widths.
  - Applies via `hyprctl dispatch resizewindowpixel exact <left_width> <height>,address:<left_addr>`.
  - Verifies resulting left/right widths against expected values with small tolerance.
  - Supports `--dry-run` to print derived state and intended target widths without applying.
- Added unit tests for width calculation, tolerance checks, and logical monitor size conversion.

## Validation run

- `cargo fmt --manifest-path rs/Cargo.toml --all` ✅
- `cargo test --manifest-path rs/Cargo.toml --all` ✅
- `cargo clippy --manifest-path rs/Cargo.toml --all` ✅
- `just check` ✅
- Dry-run on workspace `3` showed target `left=639`, `right=1277`.
- Applied run succeeded and verification matched expected widths.
- Final observed workspace `3` geometry:
  - left window `0x55a549a6cb40`: `639x1078` at `1,1`
  - right window `0x55a549a62600`: `1277x1078` at `642,1`

## Packaging follow-up

- Added Nix package output `packages.hyprctl-split` in `nix/outputs/packages.nix` using `buildRustPackage` against the `rs/` workspace and selecting package `hyprctl-split` via cargo flags.
- Added `pkgs.hyprctl-split` to `home.packages` in `nix/modules/aliases.nix`.
