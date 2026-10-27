import assert from "node:assert/strict";
import test from "node:test";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { createZmxTitleExtension, readZmxTitle, type ZmxTitleResult } from "./zmx-title.ts";

test("queries the exact canonical session with prefixing disabled", async () => {
  let invocation:
    | {
        args: string[];
        options: { env: NodeJS.ProcessEnv; timeout: number; maxBuffer: number };
      }
    | undefined;

  const result = await readZmxTitle("work-api", async (args, options) => {
    invocation = { args, options };
    return { stdout: "  Billing work  \n" };
  });

  assert.deepEqual(result, { kind: "title", title: "Billing work" });
  assert.deepEqual(invocation?.args, ["get", "work-api", "title"]);
  assert.equal(invocation?.options.env.ZMX_SESSION_PREFIX, "");
  assert.ok((invocation?.options.timeout ?? 0) > 0);
  assert.ok((invocation?.options.maxBuffer ?? 0) > 0);
});

test("distinguishes a missing title from a transient query error", async () => {
  const absent = await readZmxTitle("work-api", async () => {
    throw Object.assign(new Error("failed"), {
      stderr: 'error: label key "title" not found in session "work-api"',
    });
  });
  const failed = await readZmxTitle("work-api", async () => {
    throw new Error("zmx unavailable");
  });

  assert.deepEqual(absent, { kind: "absent" });
  assert.deepEqual(failed, { kind: "error" });
});

test("updates renamed titles and removes a cleared title", async () => {
  const originalSession = process.env.ZMX_SESSION;
  process.env.ZMX_SESSION = "22 oct 26 11:47";

  const handlers = new Map<string, (...args: never[]) => unknown>();
  const statuses: Array<{ value: string | undefined; align?: string }> = [];
  const results: ZmxTitleResult[] = [
    { kind: "title", title: "Footer work" },
    { kind: "title", title: "Renamed work" },
    { kind: "absent" },
  ];
  let intervalCallback: (() => void) | undefined;
  let intervalCleared = false;

  const extension = createZmxTitleExtension({
    readTitle: async () => results.shift() ?? { kind: "error" },
    setInterval: (callback) => {
      intervalCallback = callback;
      return { unref() {} } as ReturnType<typeof setInterval>;
    },
    clearInterval: () => {
      intervalCleared = true;
    },
  });
  const context = {
    hasUI: true,
    mode: "tui",
    ui: {
      setStatus: (_key: string, value: string | undefined, options?: { align?: string }) =>
        statuses.push({ value, align: options?.align }),
    },
  } as unknown as ExtensionContext;

  try {
    extension({ on: (event: string, handler: (...args: never[]) => unknown) => handlers.set(event, handler) } as unknown as ExtensionAPI);
    handlers.get("session_start")?.({} as never, context as never);
    await new Promise((resolve) => setTimeout(resolve, 0));
    assert.deepEqual(statuses.at(-1), { value: "Footer work", align: "right" });

    intervalCallback?.();
    await new Promise((resolve) => setTimeout(resolve, 0));
    assert.deepEqual(statuses.at(-1), { value: "Renamed work", align: "right" });

    intervalCallback?.();
    await new Promise((resolve) => setTimeout(resolve, 0));
    assert.deepEqual(statuses.at(-1), { value: undefined, align: undefined });

    handlers.get("session_shutdown")?.({} as never, context as never);
    assert.equal(intervalCleared, true);
  } finally {
    if (originalSession === undefined) delete process.env.ZMX_SESSION;
    else process.env.ZMX_SESSION = originalSession;
  }
});

test("does not query outside TUI mode or outside ZMX", async () => {
  const originalSession = process.env.ZMX_SESSION;
  let queries = 0;
  const handlers = new Map<string, (...args: never[]) => unknown>();
  const extension = createZmxTitleExtension({
    readTitle: async () => {
      queries += 1;
      return { kind: "title", title: "Unexpected" };
    },
  });
  extension({ on: (event: string, handler: (...args: never[]) => unknown) => handlers.set(event, handler) } as unknown as ExtensionAPI);

  const context = {
    hasUI: true,
    mode: "rpc",
    ui: { setStatus() {} },
  } as unknown as ExtensionContext;

  try {
    process.env.ZMX_SESSION = "work-api";
    handlers.get("session_start")?.({} as never, context as never);
    await Promise.resolve();

    context.mode = "tui";
    delete process.env.ZMX_SESSION;
    handlers.get("session_start")?.({} as never, context as never);
    await Promise.resolve();

    assert.equal(queries, 0);
  } finally {
    handlers.get("session_shutdown")?.({} as never, context as never);
    if (originalSession === undefined) delete process.env.ZMX_SESSION;
    else process.env.ZMX_SESSION = originalSession;
  }
});

test("does not restore a stale title after shutdown", async () => {
  const originalSession = process.env.ZMX_SESSION;
  process.env.ZMX_SESSION = "work-api";

  const handlers = new Map<string, (...args: never[]) => unknown>();
  const statuses: Array<string | undefined> = [];
  let resolveTitle: ((result: ZmxTitleResult) => void) | undefined;
  const extension = createZmxTitleExtension({
    readTitle: () => new Promise((resolve) => (resolveTitle = resolve)),
  });
  const context = {
    hasUI: true,
    mode: "tui",
    ui: { setStatus: (_key: string, value: string | undefined) => statuses.push(value) },
  } as unknown as ExtensionContext;

  try {
    extension({ on: (event: string, handler: (...args: never[]) => unknown) => handlers.set(event, handler) } as unknown as ExtensionAPI);
    handlers.get("session_start")?.({} as never, context as never);
    handlers.get("session_shutdown")?.({} as never, context as never);
    resolveTitle?.({ kind: "title", title: "Stale title" });
    await new Promise((resolve) => setTimeout(resolve, 0));

    assert.equal(statuses.at(-1), undefined);
  } finally {
    if (originalSession === undefined) delete process.env.ZMX_SESSION;
    else process.env.ZMX_SESSION = originalSession;
  }
});
