# Session: 2026-03-06-hyprland-workspace-management-research

## Work Summary
- Goal: research Hyprland workspace-management options from the specified official documentation index pages.
- Output delivered: config-time vs runtime option map with directives/dispatchers, caveats, and per-group source URLs.

## Detailed Breakdown
- Retrieved the exact docs requested by the user:
  - `https://wiki.hypr.land/Configuring/Workspace-Rules/`
  - `https://wiki.hypr.land/Configuring/Dispatchers/`
  - `https://wiki.hypr.land/Configuring/Binds/`
  - `https://wiki.hypr.land/Configuring/Keywords/`
  - `https://wiki.hypr.land/Configuring/Variables/`
  - `https://wiki.hypr.land/Configuring/Using-hyprctl/`
  - `https://wiki.hypr.land/IPC/`
- Parsed workspace-relevant sections from cached outputs with targeted extraction:
  - workspace rules selector syntax and rule keys,
  - workspace dispatcher names and workspace selector forms,
  - bind patterns for wheel and workspace switching examples,
  - workspace-related variable keys (`binds`, `gestures`, animation/cursor behavior),
  - hyprctl runtime control and info endpoints,
  - IPC workspace event names.
- Used `rg` token extraction for minified single-line HTML sections where line-level reads truncated long tables.

## Reasoning and Decisions
- Kept scope strictly to the user-provided official docs index URLs and their documented content.
- Grouped findings by config-time (static config and live `keyword` updates) vs runtime (dispatch, hyprctl, IPC) to match requested output shape.
- Preferred exact directive/dispatcher names from docs over inferred aliases.

## Validation
- Cross-checked repeated names across docs (e.g., `workspace`, `movetoworkspace`, `togglespecialworkspace`, `workspace_back_and_forth`).
- Verified workspace selector and caveat statements directly from `Workspace Rules` and `Dispatchers` sections.

## Learnings
- Hyprland docs embed many option tables into long minified HTML lines; token extraction is useful to avoid missing names in truncated reads.
- Workspace behavior spans multiple docs: rules + dispatchers + binds + variables + hyprctl + IPC events.

## Bugs Encountered and Solutions
- **Issue:** read output truncation for very long HTML lines prevented full table inspection.
- **Fix:** used `rg -o` token extraction on saved tool-output files to enumerate exact option/dispatcher/event names.
