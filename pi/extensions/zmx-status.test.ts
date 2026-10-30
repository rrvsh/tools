import assert from "node:assert/strict";
import test from "node:test";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import {
  clearZmxStatus,
  createZmxStatusExtension,
  publishZmxStatus,
  type ZmxPiState,
} from "./zmx-status.ts";

type Handler = (...args: never[]) => unknown;

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

const register = (extension: ReturnType<typeof createZmxStatusExtension>) => {
  const handlers = new Map<string, Handler>();
  extension({ on: (event: string, handler: Handler) => handlers.set(event, handler) } as unknown as ExtensionAPI);
  return handlers;
};

const invoke = async (handlers: Map<string, Handler>, event: string) => {
  await handlers.get(event)?.({} as never, {} as never);
  await flush();
};

test("publishes and clears canonical ZMX labels", async () => {
  const invocations: Array<{ args: string[]; prefix: string | undefined }> = [];
  const runner = async (args: string[], options: { env: NodeJS.ProcessEnv }) => {
    invocations.push({ args, prefix: options.env.ZMX_SESSION_PREFIX });
    return {};
  };

  await publishZmxStatus("work-api", "working", 1234, 5678, runner);
  await clearZmxStatus("work-api", runner);

  assert.deepEqual(invocations, [
    {
      args: ["set", "work-api", "pi_state=working", "pi_pid=1234", "pi_heartbeat=5678"],
      prefix: "",
    },
    {
      args: ["set", "work-api", "pi_state=", "pi_pid=", "pi_heartbeat="],
      prefix: "",
    },
  ]);
});

test("tracks working, prompts, settlement, heartbeats, and shutdown", async () => {
  const originalSession = process.env.ZMX_SESSION;
  process.env.ZMX_SESSION = "work-api";
  const updates: Array<{ state: ZmxPiState; pid: number; heartbeat: number }> = [];
  const cleared: string[] = [];
  let intervalCallback: (() => void) | undefined;
  let intervalMs = 0;
  let intervalCleared = false;
  let now = 12_345_000;

  const handlers = register(
    createZmxStatusExtension({
      publish: async (_session, state, pid, heartbeat) => updates.push({ state, pid, heartbeat }),
      clear: async (session) => {
        cleared.push(session);
      },
      now: () => now,
      pid: 4321,
      setInterval: (callback, milliseconds) => {
        intervalCallback = callback;
        intervalMs = milliseconds;
        return { unref() {} } as ReturnType<typeof setInterval>;
      },
      clearInterval: () => {
        intervalCleared = true;
      },
    }),
  );

  try {
    await invoke(handlers, "session_start");
    assert.deepEqual(updates.at(-1), { state: "waiting", pid: 4321, heartbeat: 12_345 });
    assert.equal(intervalMs, 10_000);

    await invoke(handlers, "agent_start");
    assert.equal(updates.at(-1)?.state, "working");

    await invoke(handlers, "ui_prompt_start");
    assert.equal(updates.at(-1)?.state, "waiting");

    await invoke(handlers, "ui_prompt_end");
    assert.equal(updates.at(-1)?.state, "working");

    now = 12_355_000;
    intervalCallback?.();
    await flush();
    assert.deepEqual(updates.at(-1), { state: "working", pid: 4321, heartbeat: 12_355 });

    await invoke(handlers, "agent_settled");
    assert.equal(updates.at(-1)?.state, "waiting");

    await invoke(handlers, "ui_prompt_end");
    assert.equal(updates.at(-1)?.state, "waiting");

    await invoke(handlers, "session_shutdown");
    assert.equal(intervalCleared, true);
    assert.deepEqual(cleared, ["work-api"]);
  } finally {
    if (originalSession === undefined) delete process.env.ZMX_SESSION;
    else process.env.ZMX_SESSION = originalSession;
  }
});

test("does nothing outside ZMX", async () => {
  const originalSession = process.env.ZMX_SESSION;
  delete process.env.ZMX_SESSION;
  let publishes = 0;
  let clears = 0;
  const handlers = register(
    createZmxStatusExtension({
      publish: async () => {
        publishes += 1;
      },
      clear: async () => {
        clears += 1;
      },
    }),
  );

  try {
    await invoke(handlers, "session_start");
    await invoke(handlers, "agent_start");
    await invoke(handlers, "agent_settled");
    await invoke(handlers, "session_shutdown");
    assert.equal(publishes, 0);
    assert.equal(clears, 0);
  } finally {
    if (originalSession === undefined) delete process.env.ZMX_SESSION;
    else process.env.ZMX_SESSION = originalSession;
  }
});

test("monitoring failures do not escape lifecycle handlers", async () => {
  const originalSession = process.env.ZMX_SESSION;
  process.env.ZMX_SESSION = "work-api";
  const handlers = register(
    createZmxStatusExtension({
      publish: async () => {
        throw new Error("unavailable");
      },
      clear: async () => {
        throw new Error("unavailable");
      },
    }),
  );

  try {
    await invoke(handlers, "session_start");
    await invoke(handlers, "agent_start");
    await invoke(handlers, "agent_settled");
    await invoke(handlers, "session_shutdown");
  } finally {
    if (originalSession === undefined) delete process.env.ZMX_SESSION;
    else process.env.ZMX_SESSION = originalSession;
  }
});

test("shutdown prevents an older queued update from restoring status", async () => {
  const originalSession = process.env.ZMX_SESSION;
  process.env.ZMX_SESSION = "work-api";
  const updates: ZmxPiState[] = [];
  let release: (() => void) | undefined;
  let first = true;
  const handlers = register(
    createZmxStatusExtension({
      publish: async (_session, state) => {
        if (first) {
          first = false;
          await new Promise<void>((resolve) => {
            release = resolve;
          });
        }
        updates.push(state);
      },
      clear: async () => {},
    }),
  );

  try {
    const starting = handlers.get("session_start")?.({} as never, {} as never) as Promise<void>;
    await flush();
    const working = handlers.get("agent_start")?.({} as never, {} as never) as Promise<void>;
    const stopping = handlers.get("session_shutdown")?.({} as never, {} as never) as Promise<void>;
    release?.();
    await Promise.all([starting, working, stopping]);
    assert.deepEqual(updates, ["waiting"]);
  } finally {
    if (originalSession === undefined) delete process.env.ZMX_SESSION;
    else process.env.ZMX_SESSION = originalSession;
  }
});
