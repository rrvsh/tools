import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

interface DefaultModelConfig {
  provider: string;
  model: string;
}

const configPath = join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "pi", "default-model.json");

const hasCliModelOverride = () =>
  process.argv.slice(2).some((arg) =>
    ["--model", "--models", "--provider"].some((option) => arg === option || arg.startsWith(`${option}=`)),
  );

const loadConfig = (): DefaultModelConfig | undefined => {
  try {
    const config: unknown = JSON.parse(readFileSync(configPath, "utf8"));
    if (
      typeof config !== "object" ||
      config === null ||
      !("provider" in config) ||
      !("model" in config) ||
      typeof config.provider !== "string" ||
      typeof config.model !== "string" ||
      config.provider.length === 0 ||
      config.model.length === 0
    ) {
      throw new Error("provider and model must be non-empty strings");
    }
    return { provider: config.provider, model: config.model };
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return undefined;
    }
    throw error;
  }
};

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (event, ctx) => {
    if (event.reason === "reload" || event.reason === "resume" || event.reason === "fork") {
      return;
    }
    if (event.reason === "startup" && ctx.sessionManager.getEntries().some((entry) => entry.type === "message")) {
      return;
    }
    if (hasCliModelOverride() || (ctx.scopedModels?.length ?? 0) > 0) {
      return;
    }

    let config: DefaultModelConfig | undefined;
    try {
      config = loadConfig();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Invalid default model config at ${configPath}: ${message}`, "warning");
      return;
    }
    if (!config) {
      return;
    }

    const model = ctx.modelRegistry.find(config.provider, config.model);
    if (!model) {
      ctx.ui.notify(`Default model is unavailable: ${config.provider}/${config.model}`, "warning");
      return;
    }
    if (ctx.model?.provider === model.provider && ctx.model.id === model.id) {
      return;
    }

    const success = await pi.setModel(model);
    if (!success) {
      ctx.ui.notify(`Default model has no configured authentication: ${config.provider}/${config.model}`, "warning");
    }
  });
}
