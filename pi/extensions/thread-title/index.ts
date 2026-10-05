import { uuidv7, type UserMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { buildTitleContext } from "./context.ts";
import {
  TITLE_SYSTEM_PROMPT,
  createTitleRequestOptions,
  fallbackTitle,
  normalizeTitle,
  renderTitleContext,
} from "./prompt.ts";

const ENTRY_TYPE = "thread-title";
const WORKING_TITLE = "...";
const EMPTY_TITLE = "pi";

interface ThreadTitleEntry {
  title: string;
}

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

const restoredTitle = (entries: readonly unknown[]): string | undefined => {
  for (let index = entries.length - 1; index >= 0; index--) {
    const value = entries[index];
    if (!value || typeof value !== "object") {
      continue;
    }

    const entry = value as {
      type?: string;
      customType?: string;
      data?: unknown;
    };

    if (
      entry.type !== "custom" ||
      entry.customType !== ENTRY_TYPE ||
      !entry.data ||
      typeof entry.data !== "object"
    ) {
      continue;
    }

    const title = (entry.data as { title?: unknown }).title;
    if (typeof title === "string") {
      return normalizeTitle(title);
    }
  }

  return undefined;
};

export default function (pi: ExtensionAPI) {
  let currentTitle: string | undefined;
  let persistedTitle: string | undefined;
  let turnNeedsTitle = false;
  let requestId = 0;
  let requestController: AbortController | undefined;

  const showIdle = (ctx: ExtensionContext) => {
    if (ctx.mode === "tui") {
      ctx.ui.setTitle(currentTitle ?? EMPTY_TITLE);
    }
  };

  const cancelRequest = () => {
    requestId++;
    requestController?.abort();
    requestController = undefined;
  };

  const saveTitle = (title: string) => {
    if (title === persistedTitle) {
      return;
    }

    pi.appendEntry<ThreadTitleEntry>(ENTRY_TYPE, { title });
    persistedTitle = title;
  };

  const updateTitle = async (ctx: ExtensionContext, expectedRequestId: number): Promise<void> => {
    const titleContext = buildTitleContext(ctx.sessionManager.getBranch(), currentTitle);
    const fallback =
      currentTitle ?? fallbackTitle(titleContext.latestUserMessage ?? "") ?? EMPTY_TITLE;

    // The main agent is idle now. Restore a usable title immediately while
    // the optional model-generated update runs in the background.
    currentTitle = fallback;
    showIdle(ctx);

    if (!ctx.model) {
      saveTitle(fallback);
      return;
    }

    const controller = new AbortController();
    requestController = controller;

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
        createTitleRequestOptions(ctx.model.api, controller.signal, uuidv7()),
      );

      if (controller.signal.aborted || expectedRequestId !== requestId) {
        return;
      }

      const generated = responseText(response.content);
      currentTitle = normalizeTitle(generated) ?? fallback;
      saveTitle(currentTitle);
      showIdle(ctx);
    } catch {
      if (controller.signal.aborted || expectedRequestId !== requestId) {
        return;
      }

      currentTitle = fallback;
      saveTitle(fallback);
      showIdle(ctx);
    } finally {
      if (requestController === controller) {
        requestController = undefined;
      }
    }
  };

  pi.on("session_start", async (_event, ctx) => {
    cancelRequest();

    currentTitle = restoredTitle(ctx.sessionManager.getBranch());
    persistedTitle = currentTitle;
    turnNeedsTitle = false;

    showIdle(ctx);

    // Pi applies its built-in title after session_start handlers complete.
    // Reapply ours on the next event-loop turn so the restored title wins.
    const expectedRequestId = requestId;
    setTimeout(() => {
      if (expectedRequestId === requestId) {
        showIdle(ctx);
      }
    }, 50);
  });

  pi.on("before_agent_start", async (_event, ctx) => {
    cancelRequest();
    turnNeedsTitle = true;

    if (ctx.mode === "tui") {
      ctx.ui.setTitle(WORKING_TITLE);
    }
  });

  pi.on("agent_settled", async (_event, ctx) => {
    if (!turnNeedsTitle) {
      showIdle(ctx);
      return;
    }

    turnNeedsTitle = false;
    const expectedRequestId = ++requestId;

    if (ctx.mode === "tui") {
      ctx.ui.setTitle(WORKING_TITLE);
    }

    void updateTitle(ctx, expectedRequestId);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    cancelRequest();
    turnNeedsTitle = false;
    showIdle(ctx);
  });
}
