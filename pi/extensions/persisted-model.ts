import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

interface PersistedModelConfig {
  provider: string;
  model: string;
}

const configPath = join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "pi", "persisted-model.json");
// Fallback seed from the old host-local default file, so hosts keep their
// previously configured model until the first new selection is persisted.
const legacyConfigPath = join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "pi", "default-model.json");

const hasCliModelOverride = () =>
  process.argv.slice(2).some((arg) =>
    ["--model", "--models", "--provider"].some((option) => arg === option || arg.startsWith(`${option}=`)),
  );

const parseConfig = (path: string): PersistedModelConfig | undefined => {
  try {
    const config: unknown = JSON.parse(readFileSync(path, "utf8"));
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

const loadConfig = (): PersistedModelConfig | undefined => {
  const primary = parseConfig(configPath);
  if (primary) {
    return primary;
  }
  return parseConfig(legacyConfigPath);
};

const persistConfig = (config: PersistedModelConfig) => {
  const tmpPath = `${configPath}.tmp`;
  writeFileSync(tmpPath, JSON.stringify(config, null, 2) + "\n", "utf8");
  renameSync(tmpPath, configPath);
};

export default function (pi: ExtensionAPI) {
  // Guards against persisting the model that this extension applies itself.
  let applyingDefault = false;

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

    let config: PersistedModelConfig | undefined;
    try {
      config = loadConfig();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Invalid persisted model config at ${configPath}: ${message}`, "warning");
      return;
    }
    if (!config) {
      return;
    }

    const model = ctx.modelRegistry.find(config.provider, config.model);
    if (!model) {
      ctx.ui.notify(`Persisted model is unavailable: ${config.provider}/${config.model}`, "warning");
      return;
    }
    if (ctx.model?.provider === model.provider && ctx.model.id === model.id) {
      return;
    }

    applyingDefault = true;
    try {
      const success = await pi.setModel(model);
      if (!success) {
        ctx.ui.notify(`Persisted model has no configured authentication: ${config.provider}/${config.model}`, "warning");
      }
    } finally {
      applyingDefault = false;
    }
  });

  pi.on("model_select", async (event, ctx) => {
    if (event.source === "restore" || applyingDefault) {
      return;
    }

    const config = { provider: event.model.provider, model: event.model.id };
    let current: PersistedModelConfig | undefined;
    try {
      current = loadConfig();
    } catch {
      current = undefined;
    }
    if (current?.provider === config.provider && current.model === config.model) {
      return;
    }

    try {
      // Ensure the pi config directory exists before the first write.
      mkdirSync(dirname(configPath), { recursive: true });
      persistConfig(config);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Failed to persist model ${config.provider}/${config.model}: ${message}`, "warning");
    }
  });
}