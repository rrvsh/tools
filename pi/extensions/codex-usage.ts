import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const provider = "openai-codex";
const statusKey = "codex-usage";
const usageUrl = "https://chatgpt.com/backend-api/wham/usage";
const refreshIntervalMs = 60_000;
const requestTimeoutMs = 15_000;
const oneDaySeconds = 24 * 60 * 60;

type UsageWindow = {
  usedPercent: number;
  resetAt?: number;
  windowSeconds?: number;
};

export type Usage = {
  fiveHour?: UsageWindow;
  weekly?: UsageWindow;
};

type RawWindow = {
  used_percent?: unknown;
  reset_at?: unknown;
  limit_window_seconds?: unknown;
};

type RawUsage = {
  rate_limit?: {
    primary_window?: RawWindow | null;
    secondary_window?: RawWindow | null;
  } | null;
};

const normalizeWindow = (value: RawWindow | null | undefined): UsageWindow | undefined => {
  if (!value || typeof value.used_percent !== "number" || !Number.isFinite(value.used_percent)) {
    return undefined;
  }

  const resetAt = typeof value.reset_at === "number" && Number.isFinite(value.reset_at) ? value.reset_at : undefined;
  return {
    usedPercent: Math.max(0, Math.min(100, value.used_percent)),
    ...(resetAt !== undefined ? { resetAt: resetAt > 100_000_000_000 ? resetAt / 1000 : resetAt } : {}),
    ...(typeof value.limit_window_seconds === "number" && Number.isFinite(value.limit_window_seconds)
      ? { windowSeconds: value.limit_window_seconds }
      : {}),
  };
};

export const normalizeUsage = (value: RawUsage): Usage => {
  const primary = normalizeWindow(value.rate_limit?.primary_window);
  const secondary = normalizeWindow(value.rate_limit?.secondary_window);

  if (primary && secondary) {
    if (primary.windowSeconds !== undefined && secondary.windowSeconds !== undefined) {
      return primary.windowSeconds < secondary.windowSeconds
        ? { fiveHour: primary, weekly: secondary }
        : { fiveHour: secondary, weekly: primary };
    }
    return { fiveHour: primary, weekly: secondary };
  }

  const only = primary ?? secondary;
  if (!only) return {};
  if (only.windowSeconds !== undefined && only.windowSeconds < oneDaySeconds) {
    return { fiveHour: only };
  }

  // OpenAI now returns weekly-only quotas in primary_window for some plans.
  return { weekly: only };
};

const percentLeft = (window: UsageWindow) => Math.round(100 - window.usedPercent);

const countdown = (resetAt: number | undefined, now: number): string | undefined => {
  if (resetAt === undefined) return undefined;
  const seconds = Math.max(0, Math.round(resetAt - now / 1000));
  const days = Math.floor(seconds / 86_400);
  const hours = Math.floor((seconds % 86_400) / 3_600);
  const minutes = Math.floor((seconds % 3_600) / 60);
  if (days > 0) return `${days}d${hours > 0 ? `${hours}h` : ""}`;
  if (hours > 0) return `${hours}h${minutes > 0 ? `${minutes}m` : ""}`;
  if (minutes > 0) return `${minutes}m`;
  return `${seconds}s`;
};

export const formatUsage = (usage: Usage, now = Date.now()): string => {
  const parts = ["Codex"];
  if (usage.fiveHour) parts.push(`5h:${percentLeft(usage.fiveHour)}%`);
  if (usage.weekly) parts.push(`7d:${percentLeft(usage.weekly)}%`);
  const reset = countdown(usage.weekly?.resetAt ?? usage.fiveHour?.resetAt, now);
  if (reset) parts.push(`↺${reset}`);
  return parts.length > 1 ? parts.join(" ") : "Codex n/a";
};

const candidateModels = (ctx: ExtensionContext) => {
  const models = [ctx.model, ...ctx.modelRegistry.getAvailable(), ...ctx.modelRegistry.getAll()];
  const seen = new Set<string>();
  return models.filter((model): model is NonNullable<typeof model> => {
    if (!model || model.provider !== provider) return false;
    const key = `${model.provider}/${model.id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

const fetchUsage = async (ctx: ExtensionContext): Promise<Usage> => {
  let headers: Record<string, string> | undefined;
  for (const model of candidateModels(ctx)) {
    const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
    if (!auth.ok) continue;
    headers = Object.fromEntries(Object.entries(auth.headers ?? {}).filter((entry): entry is [string, string] => entry[1] !== null));
    if (!Object.keys(headers).some((name) => name.toLowerCase() === "authorization") && auth.apiKey) {
      headers.Authorization = `Bearer ${auth.apiKey}`;
    }
    if (Object.keys(headers).some((name) => name.toLowerCase() === "authorization")) break;
    headers = undefined;
  }
  if (!headers) throw new Error("OpenAI Codex authentication is unavailable");

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), requestTimeoutMs);
  try {
    const response = await fetch(usageUrl, { headers, signal: controller.signal });
    if (!response.ok) throw new Error(`Codex usage request returned HTTP ${response.status}`);
    return normalizeUsage((await response.json()) as RawUsage);
  } finally {
    clearTimeout(timeout);
  }
};

export default function (pi: ExtensionAPI) {
  let timer: (ReturnType<typeof setInterval> & { unref?: () => void }) | undefined;
  let generation = 0;

  const refresh = async (ctx: ExtensionContext, currentGeneration: number) => {
    if (!ctx.hasUI) return;
    try {
      const usage = await fetchUsage(ctx);
      if (currentGeneration === generation) ctx.ui.setStatus(statusKey, formatUsage(usage));
    } catch {
      if (currentGeneration === generation) ctx.ui.setStatus(statusKey, "Codex error");
    }
  };

  const start = (ctx: ExtensionContext) => {
    generation += 1;
    const currentGeneration = generation;
    if (timer) clearInterval(timer);
    timer = undefined;
    if (ctx.model?.provider !== provider) {
      if (ctx.hasUI) ctx.ui.setStatus(statusKey, undefined);
      return;
    }

    void refresh(ctx, currentGeneration);
    timer = setInterval(() => void refresh(ctx, currentGeneration), refreshIntervalMs);
    timer.unref?.();
  };

  pi.on("session_start", (_event, ctx) => start(ctx));
  pi.on("model_select", (_event, ctx) => start(ctx));
  pi.on("session_shutdown", () => {
    generation += 1;
    if (timer) clearInterval(timer);
    timer = undefined;
  });
}
