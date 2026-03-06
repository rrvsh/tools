## Task

Research official Hyprland plugin docs for workspace/window layout extension paths, plugin management, stability/version caveats, and when plugins are appropriate versus native config.

## Sources Consulted (official only)

- https://wiki.hypr.land/Plugins/
- https://wiki.hypr.land/Plugins/Using-Plugins/
- https://wiki.hypr.land/Plugins/Development/
- https://wiki.hypr.land/Plugins/Development/Getting-Started/
- https://wiki.hypr.land/Plugins/Development/Plugin-Guidelines/

## Retrieval Notes

- Fetched pages via webfetch; content came back as rendered HTML.
- Extracted authoritative text using grep/read against captured outputs.
- Focused on lines containing operational commands, caveats, API stability notes, and security warnings.

## Key Findings Captured

- Plugins are documented as adding extra functionality and having deep runtime access.
- Development docs describe plugins as dynamic objects with almost full access to Hyprland internals.
- Using docs strongly recommend hyprpm, document add/list/update/disable flows, and manual hyprctl load/unload fallback.
- Plugin guidelines document hyprpm manifests, commit pins (Hyprland commit -> plugin commit), and API-vs-internal-method stability guidance.
- Safety/stability caveats are explicit: do not trust random .so files; crash mitigation exists but may fail.

## Decisions / Interpretation

- For workspace/window layout behavior: official docs do not enumerate a dedicated "layout plugin API" on the requested index pages, but they do explicitly document near-full internal access and behavior modification scope.
- For "plugin vs native config": docs position plugins for extra/developer-level functionality, with native config not replaced by default; no hard rule is stated.

## Issues Encountered

- Webfetch returned very large HTML blobs, requiring line-targeted extraction.
- Some command snippets were in long wrapped HTML lines; verified by reading specific line ranges.

## Outcome

- Prepared concise, source-cited findings based only on official wiki pages and their linked development subpages.
