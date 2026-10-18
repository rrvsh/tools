import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

const [binary, sessionManagerModule, sessionsDir] = process.argv.slice(2);
if (!binary || !sessionManagerModule || !sessionsDir) {
  console.error("Usage: node compare-with-pi.mjs BINARY SESSION_MANAGER_MODULE SESSIONS_DIR");
  process.exit(2);
}

const child = spawn(
  binary,
  ["--sessions-dir", sessionsDir, "--no-cache", "--output", "ndjson"],
  { stdio: ["ignore", "pipe", "inherit"] },
);
const rust = [];
for await (const line of createInterface({ input: child.stdout, crlfDelay: Infinity })) {
  if (line) {
    const event = JSON.parse(line);
    if (event.type !== "pi-session-index") rust.push(event);
  }
}
const exitCode = await new Promise((resolve) => child.once("close", resolve));
if (exitCode !== 0) process.exit(exitCode ?? 1);

const { SessionManager } = await import(sessionManagerModule);
const javascript = (await SessionManager.listAll()).map((session) => ({
  path: session.path,
  id: session.id,
  cwd: session.cwd,
  name: session.name,
  parentSessionPath: session.parentSessionPath,
  createdMs: session.created.getTime(),
  modifiedMs: session.modified.getTime(),
  messageCount: session.messageCount,
  firstMessage: session.firstMessage,
  allMessagesText: session.allMessagesText,
}));
const rustByPath = new Map(rust.map((session) => [session.path, session]));
const fields = [
  "id",
  "cwd",
  "name",
  "parentSessionPath",
  "createdMs",
  "modifiedMs",
  "messageCount",
  "firstMessage",
  "allMessagesText",
];
const differences = Object.fromEntries(fields.map((field) => [field, 0]));
const examples = {};
let missing = 0;
for (const expected of javascript) {
  const actual = rustByPath.get(expected.path);
  if (!actual) {
    missing += 1;
    continue;
  }
  for (const field of fields) {
    if (expected[field] !== actual[field]) {
      differences[field] += 1;
      examples[field] ??= [];
      if (examples[field].length < 10) {
        examples[field].push({
          path: expected.path,
          javascript: field === "allMessagesText" ? expected[field]?.length : expected[field],
          rust: field === "allMessagesText" ? actual[field]?.length : actual[field],
        });
      }
    }
  }
  rustByPath.delete(expected.path);
}
const orderingDifferences = javascript.reduce(
  (count, session, index) => count + Number(session.path !== rust[index]?.path),
  0,
);
const result = {
  javascript: javascript.length,
  rust: rust.length,
  missing,
  extra: rustByPath.size,
  orderingDifferences,
  differences,
  examples,
};
console.log(JSON.stringify(result, null, 2));
if (missing || rustByPath.size || orderingDifferences || Object.values(differences).some(Boolean)) process.exit(1);
