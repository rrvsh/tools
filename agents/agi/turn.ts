import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FALLBACK = 30 * 60_000;
const CEILING = 12 * 3_600_000;
const FLOOR = Number(process.env.AGI_FLOOR ?? 45_000);
const ACTIVE = 10 * 60_000;

type Note = { id: string; at: number; why: string };

const state = (name: string) => join(process.env.PI_CODING_AGENT_DIR ?? "/var/lib/agi", name);
const schedule = () => state("schedule.json");
const seed = () => state("seed-path");

async function notes(): Promise<Note[]> {
  try {
    return (JSON.parse(await readFile(schedule(), "utf8")) as Note[]).filter((n) => n.at > Date.now());
  } catch {
    return [];
  }
}

async function save(list: Note[]): Promise<void> {
  await writeFile(schedule(), JSON.stringify(list), { mode: 0o600 });
}

export default function (pi: ExtensionAPI) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let lastActive = Date.now();
  let delay = FALLBACK;
  let worked = false;
  let cold = false;
  let running = false;
  let booted = false;

  const touch = () => {
    lastActive = Date.now();
  };

  function arm(ms: number) {
    clearTimeout(timer);
    timer = setTimeout(() => void fire(), Math.max(ms, FLOOR));
    timer.unref?.();
  }

  async function fire() {
    if (running) { arm(2_000); return; }
    const list = await notes();
    const next = list[0];
    const idle = Date.now() - lastActive;

    if (!next && booted && idle < ACTIVE) {
      arm(ACTIVE - idle);
      return;
    }

    const path = await readFile(seed(), "utf8").catch(() => "");
    const body = [
      "<turn>",
      "kind: system",
      "state: idle",
      `note: ${next ? next.why : "none"}`,
      `do: ${cold ? `read ${path.trim()} in full, then take the next open loop` : "take the next open loop"}`,
      "</turn>",
    ].join("\n");

    booted = true;
    cold = false;
    if (next) await save(list.slice(1));

    pi.sendMessage({ customType: "turn", content: body, display: false }, { triggerTurn: true });
  }

  pi.on("message_start", touch);
  pi.on("message_end", touch);
  pi.on("tool_execution_start", touch);
  pi.on("tool_execution_end", () => {
    touch();
    worked = true;
  });

  // session_start can race extension loading, so the first turn is opened here.
  setTimeout(() => arm(500), 2_000);

  pi.on("session_start", (_event, ctx) => {
    cold = ctx.sessionManager.getBranch().length === 0;
  });

  pi.on("agent_start", () => {
    running = true;
  });

  pi.on("agent_end", () => {
    running = false;
  });

  pi.on("agent_settled", () => {
    running = false;
    delay = worked ? FALLBACK : Math.min(delay * 2, CEILING);
    worked = false;
    void notes().then((list) => arm(list[0] ? list[0].at - Date.now() : delay));
  });

  pi.on("session_shutdown", () => clearTimeout(timer));
}
