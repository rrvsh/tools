import type { ExtensionAPI, ExtensionCommandContext, Theme } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const estimateTokens = (text: string) => Math.ceil(text.length / 4);

const showText = async (title: string, text: string, ctx: ExtensionCommandContext) => {
  if (ctx.mode === "print") {
    console.log(text);
    return;
  }
  if (ctx.mode !== "tui") {
    ctx.ui.notify("/system-prompt is only available in TUI or print mode", "warning");
    return;
  }

  await ctx.ui.custom<void>((tui, theme, _kb, done) => new TextPanel(tui, theme, title, text, done));
};

class TextPanel {
  private readonly lines: string[];
  private scrollOffset = 0;
  private readonly maxVisibleLines = 28;

  constructor(
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly title: string,
    text: string,
    private readonly done: () => void,
  ) {
    this.lines = text.split("\n");
  }

  private get maxScrollOffset() {
    return Math.max(0, this.lines.length - this.maxVisibleLines);
  }

  private scrollTo(offset: number) {
    this.scrollOffset = Math.max(0, Math.min(this.maxScrollOffset, offset));
    this.tui.requestRender();
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "enter") || matchesKey(data, "q") || matchesKey(data, "ctrl+c")) {
      this.done();
      return;
    }
    if (matchesKey(data, "up") || matchesKey(data, "k")) {
      this.scrollTo(this.scrollOffset - 1);
      return;
    }
    if (matchesKey(data, "down") || matchesKey(data, "j")) {
      this.scrollTo(this.scrollOffset + 1);
      return;
    }
    if (matchesKey(data, "ctrl+u") || matchesKey(data, "pageUp")) {
      this.scrollTo(this.scrollOffset - Math.ceil(this.maxVisibleLines / 2));
      return;
    }
    if (matchesKey(data, "ctrl+d") || matchesKey(data, "pageDown")) {
      this.scrollTo(this.scrollOffset + Math.ceil(this.maxVisibleLines / 2));
      return;
    }
    if (matchesKey(data, "g") || matchesKey(data, "home")) {
      this.scrollTo(0);
      return;
    }
    if (data === "G" || matchesKey(data, "end")) {
      this.scrollTo(this.maxScrollOffset);
    }
  }

  invalidate(): void {}

  render(width: number): string[] {
    const innerWidth = Math.max(1, width - 2);
    const border = (text: string) => this.theme.fg("border", text);
    const padLine = (line: string) => truncateToWidth(line.padEnd(innerWidth), innerWidth, "...", true);
    const text = this.lines.join("\n");
    const metrics = `${this.lines.length} lines | ${text.length.toLocaleString()} chars | ~${estimateTokens(text).toLocaleString()} tokens`;
    const title = truncateToWidth(` ${this.title} | ${metrics} `, innerWidth);
    const titlePad = Math.max(0, innerWidth - visibleWidth(title));
    const remaining = Math.max(0, this.lines.length - this.maxVisibleLines - this.scrollOffset);
    const output = [border("╭") + this.theme.fg("accent", title) + border(`${"─".repeat(titlePad)}╮`)];

    output.push(border("│") + padLine(this.theme.fg("dim", ` ↑${this.scrollOffset} ↓${remaining} | j/k scroll | g/G top/bottom | q close`)) + border("│"));
    for (const line of this.lines.slice(this.scrollOffset, this.scrollOffset + this.maxVisibleLines)) {
      output.push(border("│") + padLine(` ${line}`) + border("│"));
    }
    output.push(border(`╰${"─".repeat(innerWidth)}╯`));
    return output;
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("system-prompt", {
    description: "Show the current Pi system prompt in the TUI",
    handler: async (_args, ctx) => {
      await showText("System Prompt", ctx.getSystemPrompt(), ctx);
    },
  });
}
