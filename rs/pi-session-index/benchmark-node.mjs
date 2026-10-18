import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

const [binary, sessionsDir, cache] = process.argv.slice(2);
if (!binary || !sessionsDir) {
  console.error("Usage: node benchmark-node.mjs BINARY SESSIONS_DIR [CACHE]");
  process.exit(2);
}

const arguments_ = ["--sessions-dir", sessionsDir, "--output", "ndjson"];
if (cache) arguments_.push("--cache", cache);
else arguments_.push("--no-cache");

const started = performance.now();
const child = spawn(binary, arguments_, { stdio: ["ignore", "pipe", "inherit"] });
const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
const sessions = [];
let firstRecordMs;
for await (const line of lines) {
  if (!line) continue;
  const session = JSON.parse(line);
  session.created = new Date(session.createdMs);
  session.modified = new Date(session.modifiedMs);
  delete session.createdMs;
  delete session.modifiedMs;
  sessions.push(session);
  firstRecordMs ??= performance.now() - started;
}
const exitCode = await new Promise((resolve) => child.once("close", resolve));
if (exitCode !== 0) process.exit(exitCode ?? 1);

console.log(
  JSON.stringify(
    {
      sessions: sessions.length,
      firstRecordMs: Math.round(firstRecordMs ?? -1),
      elapsedMs: Math.round(performance.now() - started),
      rssMiB: Math.round(process.memoryUsage().rss / 1048576),
      heapUsedMiB: Math.round(process.memoryUsage().heapUsed / 1048576),
    },
    null,
    2,
  ),
);
