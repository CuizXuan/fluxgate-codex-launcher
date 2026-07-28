import assert from "node:assert/strict";
import { createHash, randomBytes } from "node:crypto";
import { once } from "node:events";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { test } from "node:test";

const companionExe = process.env.FLUXGATE_COMPANION_EXE;

function encodeFrame(payload) {
  const body = Buffer.from(payload, "utf8");
  if (body.length < 126) return Buffer.concat([Buffer.from([0x81, body.length]), body]);
  const header = Buffer.alloc(4);
  header[0] = 0x81;
  header[1] = 126;
  header.writeUInt16BE(body.length, 2);
  return Buffer.concat([header, body]);
}

function decodeFrames(buffer) {
  const messages = [];
  let offset = 0;
  while (offset + 2 <= buffer.length) {
    const second = buffer[offset + 1];
    const masked = Boolean(second & 0x80);
    let length = second & 0x7f;
    let header = 2;
    if (length === 126) {
      if (offset + 4 > buffer.length) break;
      length = buffer.readUInt16BE(offset + 2);
      header = 4;
    } else if (length === 127) {
      if (offset + 10 > buffer.length) break;
      const big = buffer.readBigUInt64BE(offset + 2);
      assert.ok(big <= BigInt(Number.MAX_SAFE_INTEGER));
      length = Number(big);
      header = 10;
    }
    const maskBytes = masked ? 4 : 0;
    if (offset + header + maskBytes + length > buffer.length) break;
    const mask = masked ? buffer.subarray(offset + header, offset + header + 4) : null;
    const payloadStart = offset + header + maskBytes;
    const payload = Buffer.from(buffer.subarray(payloadStart, payloadStart + length));
    if (mask) {
      for (let index = 0; index < payload.length; index += 1) payload[index] ^= mask[index % 4];
    }
    if ((buffer[offset] & 0x0f) === 1) messages.push(payload.toString("utf8"));
    offset = payloadStart + length;
  }
  return { messages, remainder: buffer.subarray(offset) };
}

test("native companion registers, executes Codex, and streams the result", { timeout: 20000 }, async () => {
  assert.ok(companionExe, "FLUXGATE_COMPANION_EXE is required");
  const root = await mkdtemp(join(tmpdir(), "fluxgate-companion-test-"));
  const codexHome = join(root, "codex-home");
  const workspace = join(root, "workspace");
  await mkdir(codexHome, { recursive: true });
  await mkdir(workspace, { recursive: true });
  await writeFile(join(codexHome, "auth.json"), JSON.stringify({ OPENAI_API_KEY: "test-key" }));
  const fakeCodex = join(root, "fake-codex.cmd");
  await writeFile(fakeCodex, "@echo off\r\nset /p prompt=\r\necho FAKE-CODEX:%prompt%\r\n", "utf8");

  let resolveResult;
  let rejectResult;
  const result = new Promise((resolve, reject) => {
    resolveResult = resolve;
    rejectResult = reject;
  });
  const server = createServer();
  server.on("upgrade", (request, socket) => {
    try {
      assert.equal(request.headers.authorization, "Bearer test-key");
      assert.match(request.url, /^\/api\/desktop\/bridge\/device\?/);
      const accept = createHash("sha1")
        .update(`${request.headers["sec-websocket-key"]}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
        .digest("base64");
      socket.write([
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        `Sec-WebSocket-Accept: ${accept}`,
        "",
        ""
      ].join("\r\n"));
      socket.write(encodeFrame(JSON.stringify({
        type: "exec",
        session_id: "integration-session",
        prompt: "hello"
      })));
      let buffered = Buffer.alloc(0);
      let output = "";
      socket.on("data", (chunk) => {
        buffered = Buffer.concat([buffered, chunk]);
        const decoded = decodeFrames(buffered);
        buffered = Buffer.from(decoded.remainder);
        for (const raw of decoded.messages) {
          const frame = JSON.parse(raw);
          if (frame.type === "output") output += frame.data || "";
          if (frame.type === "error") rejectResult(new Error(frame.message));
          if (frame.type === "done") resolveResult({ output, exitCode: frame.exit_code });
        }
      });
      socket.on("error", rejectResult);
    } catch (error) {
      rejectResult(error);
    }
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const { port } = server.address();
  await writeFile(join(root, "companion.json"), JSON.stringify({
    SiteBaseUrl: `http://127.0.0.1:${port}`,
    CodexHome: codexHome,
    CodexBin: fakeCodex,
    Workdir: workspace,
    DeviceId: "integration-device",
    DeviceName: "integration-desktop",
    MaxRunMs: 10000
  }));

  const child = spawn(companionExe, [], {
    windowsHide: true,
    env: {
      ...process.env,
      FLUXGATE_COMPANION_ROOT: root,
      FLUXGATE_COMPANION_MUTEX: `Local\\FluxGateAI-Companion-Test-${randomBytes(8).toString("hex")}`
    }
  });
  try {
    const completed = await result;
    assert.equal(completed.exitCode, 0);
    assert.match(completed.output, /FAKE-CODEX:hello/);
  } finally {
    child.kill();
    server.close();
    await once(server, "close");
  }
});
