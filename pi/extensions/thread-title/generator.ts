import type { UserMessage } from "@earendil-works/pi-ai";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

import type { ThreadTitleContext } from "./context.ts";
import {
  TITLE_SYSTEM_PROMPT,
  createTitleRequestOptions,
  normalizeTitle,
  renderTitleContext,
} from "./prompt.ts";

const responseText = (content: unknown): string => {
  if (!Array.isArray(content)) {
    return "";
  }

  return content
    .flatMap((part) => {
      if (!part || typeof part !== "object") {
        return [];
      }

      const block = part as { type?: string; text?: string };
      return block.type === "text" && typeof block.text === "string" ? [block.text] : [];
    })
    .join("\n");
};

export const generateTitle = async (
  ctx: ExtensionContext,
  titleContext: ThreadTitleContext,
  fallback: string,
  signal: AbortSignal,
  sessionId: string,
): Promise<string> => {
  if (!ctx.model) {
    return fallback;
  }

  try {
    const message: UserMessage = {
      role: "user",
      content: [{ type: "text", text: renderTitleContext(titleContext) }],
      timestamp: Date.now(),
    };

    const response = await ctx.modelRegistry.complete(
      ctx.model,
      {
        systemPrompt: TITLE_SYSTEM_PROMPT,
        messages: [message],
      },
      createTitleRequestOptions(ctx.model.api, signal, sessionId),
    );

    return normalizeTitle(responseText(response.content)) ?? fallback;
  } catch {
    return fallback;
  }
};
