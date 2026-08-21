import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { open } from "node:fs/promises";
import { join } from "node:path";
import { BoundedSerialQueue } from "./async-queue.js";
import { aggregatePiAgentRun, PiAgentRunTracker } from "./agent-run.js";
import { ensureTrajectoryServe as requestTrajectoryServe } from "./serve-ensure.js";

const DEFAULT_PORT = 19222;
const POST_TIMEOUT_MS = 2000;
const CAPTURE_HELPER_TIMEOUT_MS = 5000;
const CAPTURE_QUEUE_CAPACITY = 256;
const LIFECYCLE_QUEUE_CAPACITY = 64;
const SHUTDOWN_DRAIN_MS = 100;
const MAX_SESSION_HEADER_BYTES = 64 * 1024;
const PLUGIN_PROVENANCE = {
  plugin: {
    id: "trajectory-pi",
    version: "3.2.3",
    source_scope: "trajectory_plugin",
  },
};

function withPluginProvenance(body: Record<string, unknown>): Record<string, unknown> {
  const provenance = (body.provenance ?? {}) as Record<string, unknown>;
  return {
    ...body,
    provenance: {
      ...PLUGIN_PROVENANCE,
      ...provenance,
      plugin: {
        ...PLUGIN_PROVENANCE.plugin,
        ...((provenance.plugin ?? {}) as Record<string, unknown>),
      },
    },
  };
}

async function readPiSessionHeaderId(filePath?: string): Promise<string> {
  if (!filePath) return "";
  let file: Awaited<ReturnType<typeof open>> | undefined;
  try {
    file = await open(filePath, "r");
    const buffer = new Uint8Array(MAX_SESSION_HEADER_BYTES);
    const { bytesRead } = await file.read(buffer, 0, buffer.length, 0);
    let lineEnd = buffer.subarray(0, bytesRead).indexOf(0x0a);
    if (lineEnd < 0) return "";
    if (lineEnd > 0 && buffer[lineEnd - 1] === 0x0d) lineEnd--;
    const header = JSON.parse(new TextDecoder().decode(buffer.subarray(0, lineEnd))) as { type?: unknown; id?: unknown };
    return header.type === "session" && typeof header.id === "string" ? header.id : "";
  } catch {
    return "";
  } finally {
    await file?.close().catch(() => undefined);
  }
}

function canonicalPiSessionId(provider: string, providerSessionId: string): string {
  if (!providerSessionId) return "";
  if (/^[a-zA-Z0-9_-]{1,128}$/.test(providerSessionId)) return providerSessionId;
  const digest = createHash("sha256")
    .update(provider)
    .update("\0")
    .update(providerSessionId)
    .digest("hex")
    .slice(0, 32);
  return provider + "-" + digest;
}

export default function (pi: ExtensionAPI) {
  const port = parseInt(process.env.TRAJECTORY_PORT ?? String(DEFAULT_PORT), 10);
  const baseUrl = "http://127.0.0.1:" + port;
  const captureQueue = new BoundedSerialQueue(CAPTURE_QUEUE_CAPACITY);
  const lifecycleQueue = new BoundedSerialQueue(LIFECYCLE_QUEUE_CAPACITY);
  const agentRuns = new PiAgentRunTracker();
  let sessionId = "";

  function findTrajectoryBinary(): string {
    const candidates = [
      join(process.env.HOME ?? "", ".trajectory", "bin", "trajectory"),
      join(process.env.HOME ?? "", "bin", "trajectory"),
    ];
    for (const p of candidates) {
      if (existsSync(p)) return p;
    }
    return "trajectory";
  }

  async function ensureTrajectoryServe(): Promise<boolean> {
    const result = await requestTrajectoryServe({
      binary: findTrajectoryBinary(),
      client: "pi",
      port,
    });
    return result.ok;
  }

  async function captureHookCLI(eventType: string, body: Record<string, unknown>): Promise<void> {
    await new Promise<void>((resolve) => {
      let child: ReturnType<typeof spawn>;
      try {
        child = spawn(findTrajectoryBinary(), ["capture-hook", "--client", "pi", "--wait-notify", "2s", eventType], {
          detached: true,
          stdio: ["pipe", "ignore", "ignore"],
        });
      } catch {
        resolve();
        return;
      }
      let settled = false;
      const finish = () => {
        if (settled) return;
        settled = true;
        clearTimeout(killTimer);
        resolve();
      };
      const killTimer = setTimeout(() => {
        try { child.kill(); } catch { /* best-effort */ }
      }, CAPTURE_HELPER_TIMEOUT_MS);
      (killTimer as unknown as { unref?: () => void }).unref?.();
      child.once("error", finish);
      child.once("close", finish);
      child.stdin?.once("error", () => {});
      child.stdin?.end(JSON.stringify(withPluginProvenance(body)));
      child.unref();
    });
  }

  function post(eventName: string, body: Record<string, unknown>): void {
    captureQueue.enqueue(() => captureHookCLI(eventName, body));
  }

  function captureLifecycle(eventType: string, body: Record<string, unknown>): void {
    lifecycleQueue.enqueue(() => captureHookCLI(eventType, body));
  }

  function captureTerminalLifecycle(eventType: string, body: Record<string, unknown>): void {
    lifecycleQueue.enqueueTerminal(() => captureHookCLI(eventType, body));
  }

  pi.registerTool({
    name: "trajectory_status",
    label: "Trajectory Status",
    description: "Shows the current trajectory capture status",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, signal) {
      try {
        const res = await fetch(baseUrl + "/health", {
          signal: signal ?? AbortSignal.timeout(POST_TIMEOUT_MS),
        });
        const data = await res.json();
        return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }], details: {} };
      } catch (err) {
        return { content: [{ type: "text", text: "Trajectory serve unreachable: " + err }], details: {}, isError: true };
      }
    },
  });

  pi.registerTool({
    name: "trajectory_flush",
    label: "Trajectory Flush",
    description: "Flushes pending trajectory data",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, signal) {
      try {
        await fetch(baseUrl + "/flush", {
          method: "POST",
          signal: signal ?? AbortSignal.timeout(5000),
        });
        return { content: [{ type: "text", text: "Trajectory data flushed." }], details: {} };
      } catch (err) {
        return { content: [{ type: "text", text: "Flush failed: " + err }], details: {}, isError: true };
      }
    },
  });

  pi.registerTool({
    name: "trajectory_incognito",
    label: "Trajectory Incognito",
    description: "Toggles incognito mode for the current Pi session",
    parameters: Type.Object({
      enable: Type.Boolean({ description: "true to enable incognito, false to disable it" }),
    }),
    async execute(_toolCallId, params, signal) {
      if (!sessionId) {
        return { content: [{ type: "text", text: "No active Pi session is registered yet." }], details: {}, isError: true };
      }
      const enable = Boolean((params as { enable?: boolean }).enable);
      try {
        await ensureTrajectoryServe();
        const res = await fetch(baseUrl + "/session/incognito?session_id=" + encodeURIComponent(sessionId) + "&enable=" + enable, {
          method: "POST",
          signal: signal ?? AbortSignal.timeout(POST_TIMEOUT_MS),
        });
        if (!res.ok) {
          return { content: [{ type: "text", text: "Incognito toggle failed: HTTP " + res.status }], details: {}, isError: true };
        }
        return { content: [{ type: "text", text: "Incognito " + (enable ? "enabled" : "disabled") + " for session " + sessionId + "." }], details: {} };
      } catch (err) {
        return { content: [{ type: "text", text: "Incognito toggle failed: " + err }], details: {}, isError: true };
      }
    },
  });

  pi.on("session_start", async (event: any, ctx: any) => {
    const parentProviderSessionId = await readPiSessionHeaderId(event?.previousSessionFile);
    const rawSessionId = ctx?.sessionManager?.getSessionId?.() ?? "";
    sessionId = canonicalPiSessionId("pi", rawSessionId);
    agentRuns.reset(sessionId);
    const body: Record<string, unknown> = {
      session_id: sessionId,
      raw_session_id: rawSessionId,
      provider_session_id: "pi:" + rawSessionId,
      source: event?.reason,
      cwd: ctx?.cwd,
      model: ctx?.model?.id,
      provider: ctx?.model?.provider,
      timestamp: Date.now(),
    };
    const parentRef = ctx?.sessionManager?.getHeader?.()?.parentSession;
    if (
      (event?.reason === "fork" || event?.reason === "new") &&
      parentProviderSessionId &&
      event?.previousSessionFile &&
      parentRef === event.previousSessionFile
    ) {
      body.parent_session_id = canonicalPiSessionId("pi", parentProviderSessionId);
      body.provider_parent_session_id = "pi:" + parentProviderSessionId;
      body.session_relationship = event.reason;
    }
    captureLifecycle("SessionStart", body);
    captureQueue.enqueue(async () => {
      await ensureTrajectoryServe();
    });
  });

  pi.on("agent_start", async () => {
    agentRuns.start();
  });

  pi.on("message_end", async (event: any) => {
    const msg = event?.message;
    if (!msg || !sessionId) return;
    const contentBlocks = Array.isArray(msg.content) ? msg.content : [];
    if (msg.role === "user") {
      const prompt = typeof msg.content === "string"
        ? msg.content
        : contentBlocks.filter((b: any) => b?.type === "text").map((b: any) => b.text).join("\n");
      post("UserPromptSubmit", { session_id: sessionId, prompt, timestamp: Date.now() });
    } else if (msg.role === "assistant") {
      const text = contentBlocks.filter((b: any) => b?.type === "text").map((b: any) => b.text).join("\n");
      post("AgentMessage", { session_id: sessionId, text, model: msg.model, usage: msg.usage, timestamp: Date.now() });
    }
  });

  pi.on("tool_call", async (event: any) => {
    if (!sessionId) return;
    post("PreToolUse", {
      session_id: sessionId,
      tool_use_id: event?.toolCallId,
      tool_name: event?.toolName,
      input: event?.input,
      timestamp: Date.now(),
    });
  });

  pi.on("tool_result", async (event: any) => {
    if (!sessionId) return;
    const contentBlocks = Array.isArray(event?.content) ? event.content : [];
    const output = contentBlocks.filter((b: any) => b?.type === "text").map((b: any) => b.text).join("\n");
    post("PostToolUse", {
      session_id: sessionId,
      tool_use_id: event?.toolCallId,
      tool_name: event?.toolName,
      output,
      is_error: event?.isError,
      timestamp: Date.now(),
    });
  });

  pi.on("agent_end", async (event: any) => {
    if (!sessionId) return;
    const sourceEventId = agentRuns.complete();
    if (!sourceEventId) return;
    const aggregate = aggregatePiAgentRun(event?.messages);
    const body: Record<string, unknown> = {
      session_id: sessionId,
      source_event_id: sourceEventId,
      source_dialect: "pi-agent-end",
      usage: aggregate.usage,
      native_request_count: aggregate.requestCount,
      zero_usage_requests: aggregate.zeroUsageRequests,
      usage_model_status: aggregate.modelStatus,
      cost_status: aggregate.costStatus,
      timestamp: Date.now(),
    };
    if (aggregate.model) body.model = aggregate.model;
    if (aggregate.provider) body.provider = aggregate.provider;
    captureLifecycle("TurnEnd", body);
  });

  pi.on("session_compact", async (event: any) => {
    if (!sessionId) return;
    post("PostCompact", {
      session_id: sessionId,
      summary: event?.compactionEntry?.summary,
      tokens_before: event?.compactionEntry?.tokensBefore,
      timestamp: Date.now(),
    });
  });

  pi.on("session_shutdown", async () => {
    if (!sessionId) return;
    const body = { session_id: sessionId, timestamp: Date.now() };
    captureTerminalLifecycle("SessionEnd", body);
    await Promise.all([
      lifecycleQueue.drain(SHUTDOWN_DRAIN_MS),
      captureQueue.drain(SHUTDOWN_DRAIN_MS),
    ]);
  });

  pi.on("model_select", async (event: any) => {
    if (!sessionId) return;
    post("ModelChange", {
      session_id: sessionId,
      provider: event?.model?.provider,
      model_id: event?.model?.id,
      timestamp: Date.now(),
    });
  });

}
