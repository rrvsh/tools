export const PRECEDING_USER_MESSAGE_COUNT = 2;
export const MAX_USER_MESSAGE_CHARACTERS = 500;
export const MAX_ASSISTANT_MESSAGE_CHARACTERS = 500;

export interface ThreadTitleContext {
  previousTitle?: string;
  latestUserMessage?: string;
  precedingUserMessages: string[];
  latestAssistantMessage?: string;
}

interface MessageEntry {
  type?: string;
  message?: {
    role?: string;
    content?: unknown;
  };
}

const extractText = (content: unknown): string => {
  if (typeof content === "string") {
    return content.trim();
  }
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
    .join("\n")
    .replace(/\s+/g, " ")
    .trim();
};

const truncate = (text: string, maximum: number): string => Array.from(text).slice(0, maximum).join("");

export const buildTitleContext = (
  entries: readonly unknown[],
  previousTitle?: string,
): ThreadTitleContext => {
  const userMessages: string[] = [];
  let latestAssistantMessage: string | undefined;

  for (const value of entries) {
    if (!value || typeof value !== "object") {
      continue;
    }

    const entry = value as MessageEntry;
    if (entry.type !== "message" || !entry.message) {
      continue;
    }

    const text = extractText(entry.message.content);
    if (!text) {
      continue;
    }

    if (entry.message.role === "user") {
      userMessages.push(truncate(text, MAX_USER_MESSAGE_CHARACTERS));
    } else if (entry.message.role === "assistant") {
      latestAssistantMessage = truncate(text, MAX_ASSISTANT_MESSAGE_CHARACTERS);
    }
  }

  return {
    previousTitle,
    latestUserMessage: userMessages.at(-1),
    precedingUserMessages: userMessages.slice(
      -(PRECEDING_USER_MESSAGE_COUNT + 1),
      -1,
    ),
    latestAssistantMessage,
  };
};
