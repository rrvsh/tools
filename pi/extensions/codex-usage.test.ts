import assert from "node:assert/strict";
import test from "node:test";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import codexUsage, { formatUsage, normalizeUsage } from "./codex-usage.ts";

test("labels a weekly-only primary window as 7d", () => {
  const usage = normalizeUsage({
    rate_limit: {
      primary_window: {
        used_percent: 35,
        limit_window_seconds: 604_800,
        reset_at: 1_700_086_400,
      },
    },
  });

  assert.equal(formatUsage(usage, 1_700_000_000_000), "Codex 7d:65% ↺1d");
});

test("labels two windows by duration regardless of position", () => {
  const usage = normalizeUsage({
    rate_limit: {
      primary_window: { used_percent: 40, limit_window_seconds: 604_800 },
      secondary_window: { used_percent: 20, limit_window_seconds: 18_000 },
    },
  });

  assert.equal(formatUsage(usage), "Codex 5h:80% 7d:60%");
});

test("keeps a short single window as 5h", () => {
  const usage = normalizeUsage({
    rate_limit: {
      primary_window: { used_percent: 25, limit_window_seconds: 18_000 },
    },
  });

  assert.equal(formatUsage(usage), "Codex 5h:75%");
});

test("does not restore stale status after leaving Codex", async () => {
  const handlers = new Map<string, (...args: never[]) => unknown>();
  const statuses: Array<string | undefined> = [];
  let resolveFetch: ((response: Response) => void) | undefined;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => new Promise((resolve) => (resolveFetch = resolve));

  const model = { provider: "openai-codex", id: "gpt-5.4" };
  const context = {
    hasUI: true,
    model,
    ui: { setStatus: (_key: string, value: string | undefined) => statuses.push(value) },
    modelRegistry: {
      getAvailable: () => [model],
      getAll: () => [model],
      getApiKeyAndHeaders: async () => ({ ok: true, apiKey: "test", headers: {} }),
    },
  } as unknown as ExtensionContext;

  try {
    codexUsage({ on: (event: string, handler: (...args: never[]) => unknown) => handlers.set(event, handler) } as unknown as ExtensionAPI);
    handlers.get("session_start")?.({} as never, context as never);
    await Promise.resolve();
    handlers.get("model_select")?.({} as never, { ...context, model: { provider: "anthropic", id: "test" } } as never);
    resolveFetch?.(new Response(JSON.stringify({ rate_limit: { primary_window: { used_percent: 35 } } })));
    await new Promise((resolve) => setTimeout(resolve, 0));

    assert.equal(statuses.at(-1), undefined);
    handlers.get("session_shutdown")?.();
  } finally {
    globalThis.fetch = originalFetch;
  }
});
