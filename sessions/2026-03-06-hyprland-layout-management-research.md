## Task

Research Hyprland window layout management options from official docs, focusing on dwindle/master behavior, splits, orientation, pseudotiling, floating/tiled transitions, fullscreen/maximize, grouping/tabbing, pin/lock behavior, per-window/per-workspace controls, and focus/move/swap/resize mechanics.

## Retrieval steps

- Queried official wiki pages supplied by the user via `webfetch`.
- Detected wiki HTML rendering in `webfetch`; switched to authoritative markdown sources from the Hyprland wiki GitHub repository (`hyprwm/hyprland-wiki`) using `gh api` for path discovery and raw markdown URLs for exact field names.
- Added layout-specific official pages (`Dwindle-Layout.md`, `Master-Layout.md`) because the Variables page explicitly delegates layout-specific options there.

## Sources used

- https://wiki.hypr.land/Configuring/Variables/
- https://wiki.hypr.land/Configuring/Keywords/
- https://wiki.hypr.land/Configuring/Dispatchers/
- https://wiki.hypr.land/Configuring/Window-Rules/
- https://wiki.hypr.land/Configuring/Binds/
- https://wiki.hypr.land/Configuring/Workspace-Rules/
- https://wiki.hypr.land/Configuring/Dwindle-Layout/
- https://wiki.hypr.land/Configuring/Master-Layout/

## Decisions and scope

- Returned an exhaustive list scoped to **layout management mechanics** (not all Hyprland options).
- Included exact option/dispatcher/rule names as documented.
- Grouped by function to make cross-referencing easier.
- Included bind-related mechanics relevant to movement/focus/resize behavior and input interaction.

## Notes

- Official docs use both variable options and dispatchers for behavior changes; both are required for complete coverage.
- Per-workspace layout control spans `workspace` rules and layout-specific `layoutmsg` / `layoutopt` mechanisms.
