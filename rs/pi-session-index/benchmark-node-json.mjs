import { spawn } from "node:child_process";

const [binary, sessionsDir, cache] = process.argv.slice(2);
if (!binary || !sessionsDir) {
  console.error("Usage: node benchmark-node-json.mjs BINARY SESSIONS_DIR [CACHE]");
  process.exit(2);
}

const arguments_ = ["--sessions-dir", sessionsDir, "--output", "json"];
if (cache) arguments_.push("--cache", cache);
else arguments_.push("--no-cache");

const started = performance.now();
const child = spawn(binary, arguments_, { stdio: ["ignore", "pipe", "inherit"] });
const chunks = [];
let bytes = 0;
for await (const chunk of child.stdout) {
  chunks.push(chunk);
  bytes += chunk.length;
}
const exitCode = await new Promise((resolve) => child.once("close", resolve));
if (exitCode !== 0) process.exit(exitCode ?? 1);
const receivedMs = performance.now() - started;
const sessions = JSON.parse(Buffer.concat(chunks, bytes));
for (const session of sessions) {
  session.created = new Date(session.createdMs);
  session.modified = new Date(session.modifiedMs);
  delete session.createdMs;
  delete session.modifiedMs;
}

console.log(
  JSON.stringify(
    {
      sessions: sessions.length,
      receivedMs: Math.round(receivedMs),
      elapsedMs: Math.round(performance.now() - started),
      rssMiB: Math.round(process.memoryUsage().rss / 1048576),
      heapUsedMiB: Math.round(process.memoryUsage().heapUsed / 1048576),
    },
    null,
    2,
  ),
);
