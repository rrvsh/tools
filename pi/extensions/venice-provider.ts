import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerProvider("venice", {
    baseUrl: "https://api.venice.ai/api/v1",
    api: "openai-completions",
    apiKey: "!cat /run/secrets/pi/venice-api-key",
    models: [
      {
        id: "deepseek-v4-pro-0813",
        name: "DeepSeek V4 Pro 0813",
        reasoning: true,
        input: ["text"],
        cost: { input: 1.65, output: 4.95, cacheRead: 0.165, cacheWrite: 0 },
        contextWindow: 1_000_000,
        maxTokens: 262_144,
      },
      {
        id: "qwen3-coder-480b-a35b-instruct-turbo",
        name: "Qwen 3 Coder 480B Turbo",
        reasoning: false,
        input: ["text"],
        cost: { input: 0.35, output: 1.5, cacheRead: 0.04, cacheWrite: 0 },
        contextWindow: 256_000,
        maxTokens: 65_536,
      },
      {
        id: "deepseek-v4-1-flash-1017-uncensored",
        name: "DeepSeek V4.1 Flash 1017 Uncensored",
        reasoning: true,
        input: ["text", "image"],
        cost: { input: 0.33, output: 1.32, cacheRead: 0.00825, cacheWrite: 0 },
        contextWindow: 1_000_000,
        maxTokens: 131_072,
      },
      {
        id: "openai-gpt-53-codex",
        name: "GPT-5.3 Codex",
        reasoning: true,
        input: ["text", "image"],
        cost: { input: 1.75, output: 14, cacheRead: 0.175, cacheWrite: 0 },
        contextWindow: 400_000,
        maxTokens: 128_000,
      },
    ],
  });
}
