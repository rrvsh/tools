# Pi session index experiment

Date: 2026-10-18
Host: Nemesis, x86-64 Linux
Pi: 0.99.2

## Corpus

- 928 picker-visible top-level sessions
- 2.90 GiB of JSONL
- 37,893,192 bytes of extracted search text at the time of the experiment
- individual sessions up to about 56 MiB

Nested subagent session files were excluded, matching `SessionManager.listAll()`.

## Correctness

On Nemesis, the Rust scanner and Pi's JavaScript scanner were run against the same live corpus in one command. All 928 records matched exactly for:

- path
- session ID
- cwd
- name
- parent session path
- creation time
- modified time
- message count
- first message
- complete `allMessagesText`

The comparison reported zero missing, extra, or differing records.

On Alpha, all 926 records matched except the message count of six old sessions. Direct byte-level checks found that Rust and `Buffer.toString().split("\\n")` both counted the physical JSONL records correctly. Node's streaming `readline` split several large lines differently on Darwin, producing malformed fragments and undercounting those sessions by one or two messages. No ID, path, cwd, name, parent, timestamp, first-message, or search-text result differed. The Rust count is the physical JSONL count rather than a platform-specific streaming undercount.

## Performance

These are warm-filesystem measurements. They do not claim cold-disk performance.

| Case | Wall time | Peak RSS |
|---|---:|---:|
| Pi JavaScript `SessionManager.listAll()` | 12.2 s | 324 MiB |
| Rust full scan, no cache, summary | 0.26 s | 126 MiB |
| Rust initial scan and SQLite population | 0.44 s | 135 MiB |
| Rust warm cache, summary | 0.05 s | 47 MiB |
| Rust full scan plus NDJSON serialization | 0.28 s | 126 MiB |
| Rust warm cache plus NDJSON serialization | 0.09 s | 47 MiB |
| Node bridge, full Rust scan and NDJSON parse | 0.46 s | 162 MiB |
| Node bridge, warm cache and NDJSON parse | 0.27 s | 165 MiB |

A JSON-array protocol was also tested. It used about 300 MiB RSS and was no faster overall, so NDJSON remains the preferred bridge.

## Real `pi -r` integration

A downstream Pi build used the Rust helper while retaining the current All default and JavaScript fallback. The final Home Manager package wrapper was also tested without an explicit helper path; `extraPackages` put `pi-session-index` on Pi's private `PATH` as intended.

| Case | Picker shell | All sessions loaded |
|---|---:|---:|
| Existing JavaScript implementation | 0.18 s | 11.86 s |
| Rust integration, empty cache | 0.26 s | 0.92 s |
| Rust integration, warm cache | 0.19 s | 0.51 s |
| Rust progressive integration, warm cache | 0.24 s to first result | 0.64 s |

The warm integrated result is about 19 times faster than the existing implementation, with the first selectable result appearing in about 0.24 seconds.

On Alpha, native JavaScript enumeration took 5.38 seconds and 369 MiB RSS. The final warm Rust-to-Node bridge took 0.14 seconds for the same 926-session corpus, with its first record at 0.04 seconds. Kikir's warm bridge took 0.16 seconds, with its first record at 0.06 seconds. The Nix package, Rust tests, and patched Pi package all built successfully on Apple Silicon macOS.

Mercury, the lowest-performance host, took 35.91 seconds for native JavaScript enumeration. After activation, a cold-cache picker produced its first session in 11.29 seconds and finished in 12.83 seconds. Across five warm-cache runs, the first session appeared in 1.14–1.62 seconds and full loading completed in 2.74–3.16 seconds.

## Cache behaviour

The local SQLite cache stores derived session metadata and search text. It is keyed by:

- path
- size
- nanosecond mtime and ctime
- local filesystem device and inode identity
- BLAKE3 hash of the first 4 KiB
- BLAKE3 hash of the last 4 KiB
- parser/schema version

The database is mode `0600`. It is outside the synchronized sessions directory and can be deleted safely. New, changed, replaced, truncated, and deleted files are reconciled on every scan.

A normal run after this experiment found 927 cache hits and reparsed only the active session in 1 ms. The complete helper run took 63 ms before Node bridge parsing.

## Safety and fallback

- The helper never writes session JSONL files.
- A missing helper leaves Pi's existing scanner unchanged.
- A failed helper invocation falls back to Pi's existing scanner.
- An aborted picker terminates the helper process.
- Cache writes use SQLite transactions.
- Cache lock waits are bounded to five seconds.
- Four simultaneous first-run indexers completed successfully against one empty cache; each returned all 928 sessions and the final database remained mode `0600`.
- A deliberately corrupt cache made the helper fail and Pi completed its native JavaScript fallback in 12.10 seconds.

## Validation coverage

The Rust suite covers session metadata and search extraction, malformed message payloads, invalid UTF-8 replacement, inner timestamp semantics, parse-time file errors, append and truncation invalidation, same-size replacement, cache reuse and deletion, stale-writer protection, schema migration, corrupt-cache failure, and cache permissions.

The included `compare-with-pi.mjs` harness compares every returned field and final ordering against Pi's JavaScript implementation over the live corpus. Helper failure and simultaneous-launch behaviour were also exercised through the real Pi bridge.

## Remaining rollout checks

- Review whether the helper should emit records progressively. The current complete result is already around 0.5 seconds.
- Confirm the downstream patch still applies visibly after each Pi update.
- Continue dogfooding the activated configuration across all four hosts.
