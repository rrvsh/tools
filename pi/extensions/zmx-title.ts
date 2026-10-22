import { execFile } from "node:child_process";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const statusKey = "zmx-title";
const refreshIntervalMs = 10_000;
const requestTimeoutMs = 3_000;
const maxOutputBytes = 4_096;

type Timer = ReturnType<typeof setInterval> & { unref?: () => void };
type ZmxRunner = (
  args: string[],
  options: { env: NodeJS.ProcessEnv; timeout: number; maxBuffer: number },
) => Promise<{ stdout: string }>;

export type ZmxTitleResult =
  | { kind: "title"; title: string }
  | { kind: "absent" }
  | { kind: "error" };

type Dependencies = {
  readTitle?: (session: string) => Promise<ZmxTitleResult>;
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

export const readZmxTitle = async (session: string, runner: ZmxRunner = runZmx): Promise<ZmxTitleResult> => {
  try {
    const { stdout } = await runner(["get", session, "title"], {
      env: { ...process.env, ZMX_SESSION_PREFIX: "" },
      timeout: requestTimeoutMs,
      maxBuffer: maxOutputBytes,
    });
    const title = stdout.trim();
    return title ? { kind: "title", title } : { kind: "absent" };
  } catch (error) {
    const stderr =
      typeof error === "object" && error !== null && "stderr" in error
        ? String((error as { stderr: unknown }).stderr)
        : "";
    return stderr.includes('label key "title" not found') ? { kind: "absent" } : { kind: "error" };
  }
};

export const createZmxTitleExtension = (dependencies: Dependencies = {}) => {
  const readTitle = dependencies.readTitle ?? readZmxTitle;
  const schedule = dependencies.setInterval ?? setInterval;
  const cancel = dependencies.clearInterval ?? clearInterval;

  return (pi: ExtensionAPI) => {
    let timer: Timer | undefined;
    let generation = 0;
    let refreshingGeneration: number | undefined;

    const refresh = async (ctx: ExtensionContext, session: string, currentGeneration: number) => {
      if (refreshingGeneration === currentGeneration) return;
      refreshingGeneration = currentGeneration;
      try {
        const result = await readTitle(session);
        if (currentGeneration !== generation) return;
        if (result.kind === "title") {
          ctx.ui.setStatus(statusKey, result.title, { align: "right" });
        } else if (result.kind === "absent") {
          ctx.ui.setStatus(statusKey, undefined);
        }
      } catch {
        // Keep the last successful title through transient query failures.
      } finally {
        if (refreshingGeneration === currentGeneration) refreshingGeneration = undefined;
      }
    };

    const stop = (ctx?: ExtensionContext) => {
      generation += 1;
      if (timer) cancel(timer);
      timer = undefined;
      if (ctx?.hasUI) ctx.ui.setStatus(statusKey, undefined);
    };

    const start = (ctx: ExtensionContext) => {
      stop(ctx);
      if (ctx.mode !== "tui") return;
      const session = process.env.ZMX_SESSION;
      if (!session) return;

      const currentGeneration = generation;
      void refresh(ctx, session, currentGeneration);
      timer = schedule(() => void refresh(ctx, session, currentGeneration), refreshIntervalMs);
      timer.unref?.();
    };

    pi.on("session_start", (_event, ctx) => start(ctx));
    pi.on("session_shutdown", (_event, ctx) => stop(ctx));
  };
};

export default createZmxTitleExtension();
