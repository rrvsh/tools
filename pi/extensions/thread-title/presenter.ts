import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export const DEFAULT_TITLE = "pi";

const WORKING_TITLE = "...";

export const showWorkingTitle = (ctx: ExtensionContext): void => {
  if (ctx.mode === "tui") {
    ctx.ui.setTitle(WORKING_TITLE);
  }
};

export const showIdleTitle = (
  ctx: ExtensionContext,
  title: string | undefined,
): void => {
  if (ctx.mode === "tui") {
    ctx.ui.setTitle(title ?? DEFAULT_TITLE);
  }
};
