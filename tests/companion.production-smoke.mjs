import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import WebSocket from "../bridge/node_modules/ws/wrapper.mjs";

const apiKey = process.env.FLUXGATE_API_KEY;
const companionExe = process.env.FLUXGATE_COMPANION_EXE;
assert.ok(apiKey, "FLUXGATE_API_KEY is required");
assert.ok(companionExe, "FLUXGATE_COMPANION_EXE is required");

const root = await mkdtemp(join(tmpdir(), "fluxgate-companion-production-"));
const codexHome = join(root, "codex-home");
const workspace = join(root, "workspace");
const deviceId = `native-smoke-${randomBytes(8).toString("hex")}`;
const sessionId = `session-${randomBytes(8).toString("hex")}`;
await mkdir(codexHome, { recursive: true });
await mkdir(workspace, { recursive: true });
await writeFile(join(codexHome, "auth.json"), JSON.stringify({ OPENAI_API_KEY: apiKey }));
const fakeCodex = join(root, "fake-codex.cmd");
await writeFile(fakeCodex, "@echo off\r\nset /p prompt=\r\necho PRODUCTION-NATIVE-COMPANION:%prompt%\r\n", "utf8");
await writeFile(join(root, "companion.json"), JSON.stringify({
  SiteBaseUrl: "https://api.fluxapi.cloud",
  CodexHome: codexHome,
  CodexBin: fakeCodex,
  Workdir: workspace,
  DeviceId: deviceId,
  DeviceName: "Native Companion Smoke",
  MaxRunMs: 10000
}));

const child = spawn(companionExe, [], {
  windowsHide: true,
  env: {
    ...process.env,
    FLUXGATE_COMPANION_ROOT: root,
    FLUXGATE_COMPANION_MUTEX: `Local\\FluxGateAI-Production-Smoke-${randomBytes(8).toString("hex")}`
  }
});

let socket;
try {
  const ticketResponse = await fetch("https://api.fluxapi.cloud/api/desktop/bridge/ticket", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` }
  });
  const ticketJson = await ticketResponse.json();
  assert.equal(ticketResponse.status, 200, ticketJson.message || ticketJson.error?.message || "ticket request failed");
  assert.equal(ticketJson.success, true);
  assert.ok(ticketJson.data?.ticket);

  socket = new WebSocket(
    "wss://api.fluxapi.cloud/api/desktop/bridge/phone",
    ["fluxgate-bridge", `ticket.${ticketJson.data.ticket}`]
  );
  const result = await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("production companion smoke timed out")), 20000);
    let output = "";
    let promptSent = false;
    const poll = setInterval(() => {
      if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ type: "list_devices" }));
    }, 500);
    socket.on("open", () => socket.send(JSON.stringify({ type: "list_devices" })));
    socket.on("message", (raw) => {
      const frame = JSON.parse(raw.toString());
      if (!promptSent && frame.type === "devices" && frame.devices?.some((device) => device.device_id === deviceId)) {
        promptSent = true;
        clearInterval(poll);
        socket.send(JSON.stringify({
          type: "prompt",
          device_id: deviceId,
          session_id: sessionId,
          prompt: "hello"
        }));
      } else if (frame.session_id === sessionId && frame.type === "output") {
        output += frame.data || "";
      } else if (frame.session_id === sessionId && frame.type === "error") {
        clearTimeout(timeout);
        clearInterval(poll);
        reject(new Error(frame.message));
      } else if (frame.session_id === sessionId && frame.type === "done") {
        clearTimeout(timeout);
        clearInterval(poll);
        resolve({ output, exitCode: frame.exit_code });
      }
    });
    socket.on("error", reject);
  });
  assert.equal(result.exitCode, 0);
  assert.match(result.output, /PRODUCTION-NATIVE-COMPANION:hello/);
  console.log("production native companion bridge smoke passed");
} finally {
  if (socket) socket.close();
  child.kill();
  await rm(root, { recursive: true, force: true });
}
