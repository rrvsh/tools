import assert from "node:assert/strict";
import test from "node:test";

import {
  MAX_ASSISTANT_MESSAGE_CHARACTERS,
  MAX_USER_MESSAGE_CHARACTERS,
  PRECEDING_USER_MESSAGE_COUNT,
  buildTitleContext,
} from "./thread-title/context.ts";
import {
  MAX_TITLE_CHARACTERS,
  createTitleRequestOptions,
  fallbackTitle,
  normalizeTitle,
  renderTitleContext,
} from "./thread-title/prompt.ts";

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
