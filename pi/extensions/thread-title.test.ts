import assert from "node:assert/strict";
import test from "node:test";

import {
  MAX_ASSISTANT_MESSAGE_CHARACTERS,
  MAX_USER_MESSAGE_CHARACTERS,
  PRECEDING_USER_MESSAGE_COUNT,
  buildTitleContext,
} from "./thread-title/context.ts";
import { generateTitle } from "./thread-title/generator.ts";
import {
  DEFAULT_TITLE,
  showIdleTitle,
  showWorkingTitle,
} from "./thread-title/presenter.ts";
import {
  MAX_TITLE_CHARACTERS,
  createTitleRequestOptions,
  fallbackTitle,
  normalizeTitle,
  renderTitleContext,
} from "./thread-title/prompt.ts";
import { createTitleStore } from "./thread-title/store.ts";

const message = (role: string, text: string) => ({
  type: "message",
  message: {
    role,
    content: [{ type: "text", text }],
  },
});

test("separates the latest user message from preceding context", () => {
  const entries = [
    message("user", "first topic"),
    message("assistant", "first response"),
    message("user", "second topic"),
    message("user", "third topic"),
    message("user", "fourth topic"),
  ];

  const context = buildTitleContext(entries, "Old title");

  assert.equal(context.previousTitle, "Old title");
  assert.equal(context.latestUserMessage, "fourth topic");
  assert.deepEqual(
    context.precedingUserMessages,
    ["second topic", "third topic"].slice(-PRECEDING_USER_MESSAGE_COUNT),
  );
  assert.equal(context.latestAssistantMessage, "first response");
});

test("bounds user and assistant context", () => {
  const context = buildTitleContext([
    message("user", "u".repeat(MAX_USER_MESSAGE_CHARACTERS + 20)),
    message("assistant", "a".repeat(MAX_ASSISTANT_MESSAGE_CHARACTERS + 20)),
  ]);

  assert.equal(
    Array.from(context.latestUserMessage ?? "").length,
    MAX_USER_MESSAGE_CHARACTERS,
  );
  assert.equal(
    Array.from(context.latestAssistantMessage ?? "").length,
    MAX_ASSISTANT_MESSAGE_CHARACTERS,
  );
});

test("normalizes model output to ten Unicode characters", () => {
  assert.equal(normalizeTitle('"Pi window titles."'), "Pi window");
  assert.equal(Array.from(normalizeTitle("abcdefghijklmnop") ?? "").length, MAX_TITLE_CHARACTERS);
});

test("removes common request verbs from local fallback titles", () => {
  assert.equal(fallbackTitle("Explain terminal tab titles"), "terminal t");
  assert.equal(fallbackTitle("Now discuss database backups"), "database b");
});

test("uses bounded request options for Codex", () => {
  const options = createTitleRequestOptions(
    "openai-codex-responses",
    new AbortController().signal,
    "test-session",
  );

  assert.equal(options.maxTokens, 1024);
  assert.equal(options.reasoningEffort, "minimal");
  assert.equal(options.cacheRetention, "none");
  assert.equal(options.sessionId, "test-session");
});

test("renders previous and recent context for the model", () => {
  const rendered = renderTitleContext({
    previousTitle: "Pi titles",
    latestUserMessage: "update it after each turn",
    precedingUserMessages: ["set a terminal title"],
    latestAssistantMessage: "Proposed a lifecycle.",
  });

  const parsed = JSON.parse(rendered);

  assert.equal(parsed.previousTitle, "Pi titles");
  assert.equal(parsed.latestUserMessage, "update it after each turn");
  assert.deepEqual(parsed.precedingUserMessages, ["set a terminal title"]);
  assert.equal(parsed.latestAssistantMessage, "Proposed a lifecycle.");
});

test("presents working, idle, and default TUI titles", () => {
  const titles: string[] = [];
  const ctx = {
    mode: "tui",
    ui: { setTitle: (title: string) => titles.push(title) },
  } as never;

  showWorkingTitle(ctx);
  showIdleTitle(ctx, "Tab titles");
  showIdleTitle(ctx, undefined);

  assert.deepEqual(titles, ["...", "Tab titles", DEFAULT_TITLE]);
});

test("does not present titles outside TUI mode", () => {
  const titles: string[] = [];
  const ctx = {
    mode: "print",
    ui: { setTitle: (title: string) => titles.push(title) },
  } as never;

  showWorkingTitle(ctx);
  showIdleTitle(ctx, "Tab titles");

  assert.deepEqual(titles, []);
});

test("restores and deduplicates persisted titles", () => {
  const appended: Array<{ customType: string; data: unknown }> = [];
  const store = createTitleStore({
    appendEntry: (customType: string, data: unknown) => {
      appended.push({ customType, data });
    },
  } as never);

  const restored = store.restore([
    { type: "custom", customType: "other", data: { title: "Ignored" } },
    { type: "custom", customType: "thread-title", data: { title: '"Old title."' } },
  ]);

  assert.equal(restored, "Old title");
  store.save("Old title");
  store.save("New title");
  assert.deepEqual(appended, [
    { customType: "thread-title", data: { title: "New title" } },
  ]);
});

test("generates and normalizes a title through the active model", async () => {
  let request: unknown;
  let options: { signal?: AbortSignal } | undefined;
  const signal = new AbortController().signal;
  const ctx = {
    model: { api: "test-api" },
    modelRegistry: {
      complete: async (_model: unknown, nextRequest: unknown, nextOptions: unknown) => {
        request = nextRequest;
        options = nextOptions as { signal?: AbortSignal };
        return { content: [{ type: "text", text: '"Tab titles."' }] };
      },
    },
  } as never;

  const title = await generateTitle(
    ctx,
    {
      previousTitle: "Old title",
      latestUserMessage: "Refactor tab titles",
      precedingUserMessages: [],
      latestAssistantMessage: "Ready.",
    },
    "fallback",
    signal,
    "test-session",
  );

  assert.equal(title, "Tab titles");
  assert.equal(options?.signal, signal);
  assert.equal(
    JSON.parse(
      ((request as { messages: Array<{ content: Array<{ text: string }> }> }).messages[0]
        ?.content[0]?.text ?? ""),
    ).latestUserMessage,
    "Refactor tab titles",
  );
});

test("uses the fallback when title generation is unavailable or fails", async () => {
  const titleContext = {
    latestUserMessage: "Refactor tab titles",
    precedingUserMessages: [],
  };
  const signal = new AbortController().signal;

  assert.equal(
    await generateTitle(
      { model: undefined } as never,
      titleContext,
      "fallback",
      signal,
      "test-session",
    ),
    "fallback",
  );
  assert.equal(
    await generateTitle(
      {
        model: { api: "test-api" },
        modelRegistry: {
          complete: async () => {
            throw new Error("provider failed");
          },
        },
      } as never,
      titleContext,
      "fallback",
      signal,
      "test-session",
    ),
    "fallback",
  );
});
