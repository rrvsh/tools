import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { normalizeTitle } from "./prompt.ts";

const ENTRY_TYPE = "thread-title";

interface ThreadTitleEntry {
  title: string;
}

const findRestoredTitle = (entries: readonly unknown[]): string | undefined => {
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

export const createTitleStore = (pi: ExtensionAPI) => {
  let persistedTitle: string | undefined;

  return {
    restore(entries: readonly unknown[]): string | undefined {
      persistedTitle = findRestoredTitle(entries);
      return persistedTitle;
    },

    save(title: string): void {
      if (title === persistedTitle) {
        return;
      }

      pi.appendEntry<ThreadTitleEntry>(ENTRY_TYPE, { title });
      persistedTitle = title;
    },
  };
};
