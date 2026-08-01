import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import os from "node:os";

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    return {
      systemPrompt: `Hostname: ${os.hostname()}\n\n${event.systemPrompt}`,
    };
  });
}
