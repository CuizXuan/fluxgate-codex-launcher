import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import WebSocket from "../bridge/node_modules/ws/wrapper.mjs";

const installRoot = process.env.FLUXGATE_INSTALL_ROOT
  || join(process.env.APPDATA || "", "FluxGateAICodexLauncher");
const auth = JSON.parse(await readFile(join(installRoot, "codex-home", "auth.json"), "utf8"));
const config = JSON.parse(await readFile(join(installRoot, "companion.json"), "utf8"));
const apiKey = String(auth.OPENAI_API_KEY || "").trim();
const siteBaseUrl = String(config.SiteBaseUrl || "").replace(/\/$/, "");
const deviceId = String(config.DeviceId || "").trim();

assert.ok(apiKey, "installed Launcher credential is missing");
assert.ok(siteBaseUrl, "installed companion site URL is missing");
assert.ok(deviceId, "installed companion device ID is missing");

const ticketResponse = await fetch(`${siteBaseUrl}/api/desktop/bridge/ticket`, {
  method: "POST",
  headers: { Authorization: `Bearer ${apiKey}` }
});
const ticketJson = await ticketResponse.json();
assert.equal(ticketResponse.status, 200, ticketJson.message || "ticket request failed");
assert.equal(ticketJson.success, true);
assert.ok(ticketJson.data?.ticket);

const bridgeUrl = new URL(`${siteBaseUrl}/api/desktop/bridge/phone`);
bridgeUrl.protocol = bridgeUrl.protocol === "https:" ? "wss:" : "ws:";
const socket = new WebSocket(
  bridgeUrl,
  ["fluxgate-bridge", `ticket.${ticketJson.data.ticket}`]
);
const sessionId = `installed-smoke-${randomBytes(8).toString("hex")}`;

try {
  const result = await new Promise((resolve, reject) => {
    let output = "";
    let promptSent = false;
    const timeout = setTimeout(() => reject(new Error("installed companion smoke timed out")), 120000);
    const poll = setInterval(() => {
      if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: "list_devices" }));
      }
    }, 500);

    const finish = (callback, value) => {
      clearTimeout(timeout);
      clearInterval(poll);
      callback(value);
    };

    socket.on("open", () => socket.send(JSON.stringify({ type: "list_devices" })));
    socket.on("message", (raw) => {
      const frame = JSON.parse(raw.toString());
      if (!promptSent && frame.type === "devices" && frame.devices?.some((device) => device.device_id === deviceId)) {
        promptSent = true;
        socket.send(JSON.stringify({
          type: "prompt",
          device_id: deviceId,
          session_id: sessionId,
          prompt: "Reply only REMOTE_CLI_OK"
        }));
      } else if (frame.session_id === sessionId && frame.type === "output") {
        output += frame.data || "";
      } else if (frame.session_id === sessionId && frame.type === "error") {
        finish(reject, new Error(frame.message || "remote Codex task failed"));
      } else if (frame.session_id === sessionId && frame.type === "done") {
        finish(resolve, { output, exitCode: frame.exit_code });
      }
    });
    socket.on("error", (error) => finish(reject, error));
  });

  assert.equal(result.exitCode, 0);
  assert.match(result.output, /REMOTE_CLI_OK/);
  console.log("installed production companion and real Codex smoke passed");
} finally {
  socket.close();
}
