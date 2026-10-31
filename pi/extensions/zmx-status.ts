import { execFile } from "node:child_process";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const heartbeatIntervalMs = 10_000;
const requestTimeoutMs = 3_000;
const maxOutputBytes = 4_096;

export type ZmxPiState = "working" | "waiting";
type Timer = ReturnType<typeof setInterval> & { unref?: () => void };
type ZmxRunner = (
  args: string[],
  options: { env: NodeJS.ProcessEnv; timeout: number; maxBuffer: number },
) => Promise<unknown>;

type Dependencies = {
  publish?: (session: string, state: ZmxPiState, pid: number, heartbeat: number) => Promise<void>;
  clear?: (session: string) => Promise<void>;
  now?: () => number;
  pid?: number;
  setInterval?: (callback: () => void, milliseconds: number) => Timer;
  clearInterval?: (timer: Timer) => void;
};

const runZmx: ZmxRunner = (args, options) =>
  new Promise((resolve, reject) => {
    execFile("zmx", args, { ...options, encoding: "utf8" }, (error, stdout, stderr) => {
      if (error) {
        reject(Object.assign(error, { stderr }));
        return;
      }
      resolve({ stdout });
    });
  });

const zmxOptions = () => ({
  env: { ...process.env, ZMX_SESSION_PREFIX: "" },
  timeout: requestTimeoutMs,
  maxBuffer: maxOutputBytes,
});

export const publishZmxStatus = async (
  session: string,
  state: ZmxPiState,
  pid: number,
  heartbeat: number,
  runner: ZmxRunner = runZmx,
): Promise<void> => {
  await runner(
    ["set", session, `pi_state=${state}`, `pi_pid=${pid}`, `pi_heartbeat=${heartbeat}`],
    zmxOptions(),
  );
};

export const clearZmxStatus = async (session: string, runner: ZmxRunner = runZmx): Promise<void> => {
  await runner(["set", session, "pi_state=", "pi_pid=", "pi_heartbeat="], zmxOptions());
};

export const createZmxStatusExtension = (dependencies: Dependencies = {}) => {
  const publish = dependencies.publish ?? publishZmxStatus;
  const clear = dependencies.clear ?? clearZmxStatus;
  const now = dependencies.now ?? (() => Date.now());
  const pid = dependencies.pid ?? process.pid;
  const schedule = dependencies.setInterval ?? setInterval;
  const cancel = dependencies.clearInterval ?? clearInterval;

  return (pi: ExtensionAPI) => {
    let session: string | undefined;
    let state: ZmxPiState = "waiting";
    let running = false;
    let timer: Timer | undefined;
    let generation = 0;
    let writes = Promise.resolve();

    const enqueue = (action: () => Promise<void>, currentGeneration = generation) => {
      writes = writes
        .catch(() => {})
        .then(async () => {
          if (currentGeneration !== generation) return;
          try {
            await action();
          } catch {
            // Monitoring must never interrupt Pi.
          }
        });
      return writes;
    };

    const update = (nextState: ZmxPiState) => {
      state = nextState;
      if (!session) return Promise.resolve();
      const currentSession = session;
      const heartbeat = Math.floor(now() / 1_000);
      return enqueue(() => publish(currentSession, nextState, pid, heartbeat));
    };

    const stop = async () => {
      generation += 1;
      if (timer) cancel(timer);
      timer = undefined;
      const previousSession = session;
      session = undefined;
      running = false;
      await writes.catch(() => {});
      if (!previousSession) return;
      try {
        await clear(previousSession);
      } catch {
        // A stale heartbeat expires even when cleanup cannot reach ZMX.
      }
    };

    const start = async () => {
      await stop();
      session = process.env.ZMX_SESSION;
      if (!session) return;
      state = "waiting";
      const currentGeneration = generation;
      await update(state);
      timer = schedule(() => void update(state), heartbeatIntervalMs);
      timer.unref?.();
      if (currentGeneration !== generation && timer) {
        cancel(timer);
        timer = undefined;
      }
    };

    pi.on("session_start", start);
    pi.on("agent_start", () => {
      running = true;
      return update("working");
    });
    pi.on("ui_prompt_start", () => update("waiting"));
    pi.on("ui_prompt_end", () => update(running ? "working" : "waiting"));
    pi.on("agent_settled", () => {
      running = false;
      return update("waiting");
    });
    pi.on("session_shutdown", stop);
  };
};

export default createZmxStatusExtension();
