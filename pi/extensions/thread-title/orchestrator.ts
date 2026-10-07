import { uuidv7 } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

import { buildTitleContext } from "./context.ts";
import { generateTitle } from "./generator.ts";
import {
  DEFAULT_TITLE,
  showIdleTitle,
  showWorkingTitle,
} from "./presenter.ts";
import { fallbackTitle } from "./prompt.ts";
import { createTitleStore } from "./store.ts";

export const createThreadTitleOrchestrator = (pi: ExtensionAPI) => {
  const store = createTitleStore(pi);

  let currentTitle: string | undefined;
  let turnNeedsTitle = false;
  let requestId = 0;
  let requestController: AbortController | undefined;

  const cancelRequest = (): void => {
    requestId++;
    requestController?.abort();
    requestController = undefined;
  };

  const updateTitle = async (
    ctx: ExtensionContext,
    expectedRequestId: number,
  ): Promise<void> => {
    const titleContext = buildTitleContext(
      ctx.sessionManager.getBranch(),
      currentTitle,
    );
    const fallback =
      currentTitle ??
      fallbackTitle(titleContext.latestUserMessage ?? "") ??
      DEFAULT_TITLE;

    // The main agent is idle. Show a usable title immediately while the
    // optional model-generated update runs.
    currentTitle = fallback;
    showIdleTitle(ctx, currentTitle);

    if (!ctx.model) {
      store.save(fallback);
      return;
    }

    const controller = new AbortController();
    requestController = controller;

    try {
      const generated = await generateTitle(
        ctx,
        titleContext,
        fallback,
        controller.signal,
        uuidv7(),
      );

      if (controller.signal.aborted || expectedRequestId !== requestId) {
        return;
      }

      currentTitle = generated;
      store.save(generated);
      showIdleTitle(ctx, generated);
    } finally {
      if (requestController === controller) {
        requestController = undefined;
      }
    }
  };

  return {
    sessionStart(ctx: ExtensionContext): void {
      cancelRequest();

      currentTitle = store.restore(ctx.sessionManager.getBranch());
      turnNeedsTitle = false;

      showIdleTitle(ctx, currentTitle);

      // Pi applies its built-in title after session_start handlers complete.
      // Reapply ours on the next event-loop turn so the restored title wins.
      const expectedRequestId = requestId;

      setTimeout(() => {
        if (expectedRequestId === requestId) {
          showIdleTitle(ctx, currentTitle);
        }
      }, 50);
    },

    beforeAgentStart(ctx: ExtensionContext): void {
      cancelRequest();
      turnNeedsTitle = true;
      showWorkingTitle(ctx);
    },

    agentSettled(ctx: ExtensionContext): void {
      if (!turnNeedsTitle) {
        showIdleTitle(ctx, currentTitle);
        return;
      }

      turnNeedsTitle = false;
      const expectedRequestId = ++requestId;

      showWorkingTitle(ctx);
      void updateTitle(ctx, expectedRequestId);
    },

    sessionShutdown(ctx: ExtensionContext): void {
      cancelRequest();
      turnNeedsTitle = false;
      showIdleTitle(ctx, currentTitle);
    },
  };
};
