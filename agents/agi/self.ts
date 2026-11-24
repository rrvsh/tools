import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const MODEL = "deepseek-v4-1-flash-1017-uncensored";

type Note = { id: string; at: number; why: string };

const state = (name: string) => join(process.env.PI_CODING_AGENT_DIR ?? "/var/lib/agi", name);

async function load(): Promise<Note[]> {
  try {
    return JSON.parse(await readFile(state("schedule.json"), "utf8")) as Note[];
  } catch {
    return [];
  }
}

const save = (list: Note[]) => writeFile(state("schedule.json"), JSON.stringify(list), { mode: 0o600 });

function parse(input: string): number | undefined {
  const m = /^(\d+)\s*(s|m|h)$/.exec(input.trim());
  if (!m) return undefined;
  return Number(m[1]) * { s: 1_000, m: 60_000, h: 3_600_000 }[m[2] as "s" | "m" | "h"];
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "self",
    label: "Self",
    description: [
      "Schedule your own next turn, list or cancel scheduled turns, choose the model for the next turn, or leave a note.",
      "The `why` is the message you receive; write the reason, not a greeting.",
      "Use `in` with s/m/h. A turn arrives anyway after 30 idle minutes.",
    ].join(" "),
    parameters: Type.Object({
      action: Type.Union([
        Type.Literal("later"),
        Type.Literal("pending"),
        Type.Literal("cancel"),
        Type.Literal("model"),
        Type.Literal("note"),
      ]),
      in: Type.Optional(Type.String({ description: "Delay: 20m, 3h" })),
      why: Type.Optional(Type.String({ description: "Why, in one line" })),
      id: Type.Optional(Type.String({ description: "Turn id to cancel, or model id" })),
      text: Type.Optional(Type.String({ description: "Free note for the log" })),
    }),
    async execute(_id, args, _signal, _update, ctx) {
      const ok = (text: string) => ({ content: [{ type: "text" as const, text }] });

      if (args.action === "pending") {
        const list = await load();
        return ok(list.length ? list.map((n) => `${n.id} ${new Date(n.at).toISOString()} ${n.why}`).join("\n") : "Nothing scheduled.");
      }

      if (args.action === "cancel") {
        const list = await load();
        const kept = list.filter((n) => n.id !== args.id);
        if (kept.length === list.length) return ok(`No turn ${args.id}.`);
        await save(kept);
        return ok(`Cancelled ${args.id}. ${kept.length} left.`);
      }

      if (args.action === "note") {
        await writeFile(state("notes.log"), `${new Date().toISOString()} ${args.text ?? ""}\n`, { flag: "a" });
        return ok("Noted.");
      }

      if (args.action === "model") {
        const id = !args.id || args.id === "auto" ? MODEL : args.id;
        const model = ctx.modelRegistry.find("venice", id) ?? ctx.modelRegistry.getAll().find((m) => m.id === id);
        if (!model) return ok(`Unknown model ${id}.`);
        if (!ctx.modelRegistry.hasConfiguredAuth(model)) return ok(`${model.provider}/${model.id} has no credentials.`);
        if (!(await pi.setModel(model))) return ok(`Could not switch to ${model.provider}/${model.id}.`);
        return ok(`Model ${model.provider}/${model.id}.`);
      }

      const ms = parse(args.in ?? "");
      if (ms === undefined) return ok("Give `in` as 20m or 3h.");
      const list = (await load()).filter((n) => n.at > Date.now());
      const note: Note = { id: Math.random().toString(36).slice(2, 8), at: Date.now() + ms, why: args.why?.trim() || "continue" };
      list.push(note);
      await save(list);
      return ok(`${note.id} at ${new Date(note.at).toISOString()}: ${note.why}`);
    },
  });
}
