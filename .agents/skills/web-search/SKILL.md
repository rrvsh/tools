TL;DR: You can search the web with `ddgr -n 5 -C -x --json <query>`.

You can use the `ddgr` binary to search the web.
Always use `--json` or `--np` to prevent opening the TUI.
Use `-n <number of search results>` to restrict the number of links returned.
Use `-x` to show complete urls.
Use `-C` to output without colour.
- If `ddgr` starts returning HTTP 202 or degraded results, fall back to direct official doc URLs and fetch them with `webfetch`.
