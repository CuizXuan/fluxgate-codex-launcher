import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { WebSocketServer } from "ws";

const here = dirname(fileURLToPath(import.meta.url));
const pagePath = join(here, "..", "mobile-web", "index.html");
const port = Number(process.env.MOBILE_PREVIEW_PORT || 4180);
const host = "127.0.0.1";
const devices = [{ device_id: "preview-device", device_name: "Preview Workstation" }];
const previewApiKey = "preview-api-key";
const previewTicket = "preview-ticket";

const server = createServer(async (request, response) => {
  const url = new URL(request.url || "/", `http://${request.headers.host || host}`);
  if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/index.html" || url.pathname === "/api/desktop/connect")) {
    response.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
    response.end(await readFile(pagePath));
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/desktop/codex/status") {
    response.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
    response.end(JSON.stringify({ success: true, data: { password_login_enabled: true } }));
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/desktop/codex/login") {
    request.resume();
    response.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
    response.end(JSON.stringify({ success: true, data: { api_key: previewApiKey } }));
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/desktop/bridge/ticket") {
    request.resume();
    if (request.headers.authorization !== `Bearer ${previewApiKey}`) {
      response.writeHead(401, { "content-type": "application/json" });
      response.end(JSON.stringify({ success: false, message: "API Key invalid" }));
      return;
    }
    response.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
    response.end(JSON.stringify({ success: true, data: { ticket: previewTicket, expires_in: 60 } }));
    return;
  }

  response.writeHead(404);
  response.end("Not found");
});

const webSockets = new WebSocketServer({
  noServer: true,
  handleProtocols(protocols) {
    return protocols.has("fluxgate-bridge") ? "fluxgate-bridge" : false;
  }
});
server.on("upgrade", (request, socket, head) => {
  const url = new URL(request.url || "/", `http://${request.headers.host || host}`);
  const protocols = String(request.headers["sec-websocket-protocol"] || "")
    .split(",")
    .map((value) => value.trim());
  if (url.pathname !== "/api/desktop/bridge/phone" || !protocols.includes(`ticket.${previewTicket}`)) {
    socket.destroy();
    return;
  }
  webSockets.handleUpgrade(request, socket, head, (webSocket) => webSockets.emit("connection", webSocket));
});

webSockets.on("connection", (webSocket) => {
  webSocket.send(JSON.stringify({ type: "devices", devices }));
  webSocket.on("message", (raw) => {
    let message;
    try {
      message = JSON.parse(String(raw));
    } catch {
      return;
    }
    if (message.type === "list_devices") {
      webSocket.send(JSON.stringify({ type: "devices", devices }));
      return;
    }
    if (message.type === "prompt") {
      webSocket.send(JSON.stringify({ type: "output", session_id: message.session_id, data: "Preview response: mobile Bridge is working." }));
      webSocket.send(JSON.stringify({ type: "done", session_id: message.session_id, exit_code: 0 }));
    }
  });
});

server.listen(port, host, () => {
  console.log(`FluxGate mobile preview: http://${host}:${port}/index.html`);
});
