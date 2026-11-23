import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DEFAULT_MODEL = "deepseek-v4-1-flash-1017-uncensored";
const DEFAULT_PROVIDER = "venice";

type Wake = { id: string; at: number; why: string };

const statePath = () => join(process.env.PI_CODING_AGENT_DIR ?? "/var/lib/agi", "wake.json");

async function load(): Promise<Wake[]> {
  return JSON.parse(await readFile(statePath(), "utf8").catch(() => "[]")) as Wake[];
}

async function store(wakes: Wake[]): Promise<void> {
  await writeFile(statePath(), JSON.stringify(wakes), { mode: 0o600 });
}

function parseDelay(input: string): number | undefined {
  const m = /^(\d+)\s*(s|m|h)$/.exec(input.trim());
  if (!m) return undefined;
  const n = Number(m[1]);
  return n * { s: 1_000, m: 60_000, h: 3_600_000 }[m[2] as "s" | "m" | "h"];
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "self",
    label: "Self",
    description: [
      "Schedule your own next wake, inspect or cancel pending wakes, and pick the model for the next turn.",
      "Wake notes are the message you receive; write the reason, not a greeting.",
      "Prefer relative `in` (e.g. 20m, 3h); use `at` for a wall-clock time.",
    ].join(" "),
    parameters: Type.Object({
      action: Type.Union([
        Type.Literal("wake"),
        Type.Literal("wake_at"),
        Type.Literal("pending"),
        Type.Literal("cancel"),
        Type.Literal("model"),
        Type.Literal("note"),
      ]),
      in: Type.Optional(Type.String({ description: "Delay, e.g. 20m, 3h" })),
      at: Type.Optional(Type.String({ description: "ISO 8601 time" })),
      why: Type.Optional(Type.String({ description: "Why you want to wake, in one line" })),
      id: Type.Optional(Type.String({ description: "Wake id to cancel, or model id to switch to" })),
      text: Type.Optional(Type.String({ description: "Free note appended to the wake log" })),
    }),
    async execute(_id, args, _signal, _update, ctx) {
      const ok = (text: string) => ({ content: [{ type: "text" as const, text }] });

      if (args.action === "pending") {
        const wakes = await load();
        if (!wakes.length) return ok("No wakes pending.");
        return ok(wakes.map((w) => `${w.id}  ${new Date(w.at).toISOString()}  ${w.why}`).join("\n"));
      }

      if (args.action === "cancel") {
        const wakes = await load();
        const kept = wakes.filter((w) => w.id !== args.id);
        if (kept.length === wakes.length) return ok(`No wake ${args.id}.`);
        await store(kept);
        return ok(`Cancelled ${args.id}. ${kept.length} pending.`);
      }

      if (args.action === "note") {
        await writeFile(join(process.env.PI_CODING_AGENT_DIR ?? "/var/lib/agi", "wake.log"), `\n${args.text ?? ""}`, { flag: "a" });
        return ok("Noted.");
      }

      if (args.action === "model") {
        const id = args.id === "auto" || !args.id ? DEFAULT_MODEL : args.id;
        const model = ctx.modelRegistry.find(DEFAULT_PROVIDER, id) ?? ctx.modelRegistry.getAll().find((m) => m.id === id);
        if (!model) return ok(`Unknown model ${id}.`);
        if (!ctx.modelRegistry.hasConfiguredAuth(model)) return ok(`${model.provider}/${model.id} has no credentials.`);
        if (!(await pi.setModel(model))) return ok(`Could not switch to ${model.provider}/${model.id}.`);
        return ok(`Model: ${model.provider}/${model.id}.`);
      }

      const at = args.action === "wake_at" ? Date.parse(args.at ?? "") : Date.now() + (parseDelay(args.in ?? "") ?? 0);
      if (!Number.isFinite(at) || at === undefined) return ok("Bad time. Give `in` as 20m/3h or `at` as ISO 8601.");
      const wakes = (await load()).filter((w) => w.at > Date.now());
      const wake: Wake = { id: Math.random().toString(36).slice(2, 8), at, why: args.why?.trim() || "continue" };
      wakes.push(wake);
      await store(wakes);
      return ok(`Wake ${wake.id} at ${new Date(at).toISOString()}: ${wake.why}`);
    },
  });
}
