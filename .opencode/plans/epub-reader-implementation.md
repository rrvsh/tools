EPUB Reader Implementation Plan

Branch: feat/epub-reader-browser-storage
Status: in progress

Objectives
- Add a public `/reader` single-page EPUB reader route.
- Store EPUB binaries in IndexedDB in-browser storage.
- Render books in a continuous scroll reading mode.
- Track reading progress and bookmarks per book.
- Use hash routing for deep-linking and refresh safety.
- Keep styling aligned with existing site dark aesthetic.

Delivery Plan (atomic commits)
1) Reader route and page shell
   - Add `reader` controller and route wiring.
   - Add `reader.html` template shell with app mount.
   - Add links for `reader.css` and `reader.js` plus CDN libraries.
   - Status: completed.

2) Reader frontend core (library + storage + routing)
   - IndexedDB setup (`books`, `progress` stores).
   - Library overlay for import/open/delete.
   - Hash-based router (`#bookId` and `#bookId/cfi=...`).

3) Reader rendering and persistence
   - epub.js continuous scroll rendition.
   - Save/restore CFI progress.
   - Bookmark create/list/jump/delete.
   - Reading progress indicator.

4) Site integration and polish
   - Add index link to `/reader`.
   - Reader-specific CSS aligned with existing style.
   - Mobile layout pass and UX polish.

Execution log
- 2026-04-01: Plan initialized.
- 2026-04-01: Commit 1 implementation started (route + handler + template shell).
- 2026-04-01: Commit 1 completed after green checks.
