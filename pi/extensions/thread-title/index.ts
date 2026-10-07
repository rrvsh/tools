import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { createThreadTitleOrchestrator } from "./orchestrator.ts";

export default function (pi: ExtensionAPI) {
  const orchestrator = createThreadTitleOrchestrator(pi);

  pi.on("session_start", async (_event, ctx) => {
    orchestrator.sessionStart(ctx);
  });

  pi.on("before_agent_start", async (_event, ctx) => {
    orchestrator.beforeAgentStart(ctx);
  });

  pi.on("agent_settled", async (_event, ctx) => {
    orchestrator.agentSettled(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    orchestrator.sessionShutdown(ctx);
  });
}
