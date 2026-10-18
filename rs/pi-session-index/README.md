# pi-session-index

Experimental local index for Pi JSONL sessions.

It preserves Pi's all-session metadata and full-text search input while avoiding repeated JavaScript parsing of every synchronized transcript. The SQLite cache is derived, machine-local data and can be deleted at any time.

## Usage

```sh
pi-session-index \
  --sessions-dir ~/.pi/agent/sessions \
  --cache ~/.pi/agent/cache/session-index.sqlite3 \
  --output ndjson
```

Use `--no-cache` to measure a full Rust scan. `--output summary` prints scan timings instead of session records.

The tool never writes to session JSONL files.
