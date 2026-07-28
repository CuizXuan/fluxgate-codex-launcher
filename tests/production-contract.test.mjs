import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

async function source(path) {
  return readFile(join(root, path), "utf8");
}

test("launcher consumes the production dedicated-key login response", async () => {
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");
  assert.match(gui, /loginResp\.data\.api_key/);
  assert.doesNotMatch(gui, /desktop\/codex\/token|loginResp\.data\.access_token/);
  assert.match(gui, /\$DefaultModel\s+=\s+'gpt-5\.4-mini'/);
  assert.match(gui, /\$GatewayBaseUrl\s+=\s+'https:\/\/api\.fluxapi\.cloud\/v1'/);
});

test("desktop Bridge uses a dedicated API key header", async () => {
  const bridge = await source("bridge/fluxgate-bridge.mjs");
  assert.match(bridge, /j\.data\.api_key/);
  assert.match(bridge, /Authorization: `Bearer \$\{this\.cfg\.apiKey\}`/);
  assert.doesNotMatch(bridge, /bridge\/device\?token=|j\.data\.access_token/);
});

test("Launcher embeds the native background companion and reuses isolated credentials", async () => {
  const bootstrapper = await source("src/LauncherBootstrapper.cs");
  const companion = await source("src/Companion.cs");
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");

  assert.match(bootstrapper, /FluxGate\.CodexLauncher\.Companion/);
  assert.match(bootstrapper, /FLUXGATE_COMPANION_SOURCE/);
  assert.match(companion, /Path\.Combine\(config\.CodexHome, "auth\.json"\)/);
  assert.match(companion, /SetRequestHeader\("Authorization", "Bearer " \+ apiKey\)/);
  assert.match(companion, /exec --skip-git-repo-check -s workspace-write -/);
  assert.doesNotMatch(companion, /Log\([^\n]*prompt/);
  assert.match(gui, /FluxGate-Codex-Companion\.exe/);
  assert.match(gui, /FluxGateAI Codex Companion\.lnk/);
  assert.match(gui, /api\/desktop\/bridge\/ticket/);
  assert.match(gui, /desktop-codex 的专用 API Key/);
  assert.doesNotMatch(gui, /companionConfig[\s\S]{0,500}ApiKey\s*=/);
});

test("installers use a dedicated Codex binary instead of the global CLI", async () => {
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");
  const cli = await source("installer/FluxGate-Codex-Setup.ps1");

  assert.match(gui, /Join-Path \$binDir 'codex\.exe'/);
  assert.match(cli, /Join-Path \$InstallDir 'codex\.exe'/);
  assert.doesNotMatch(gui, /npm install -g|Get-Command codex/);
  assert.doesNotMatch(cli, /npm install -g|Get-Command codex/);
  assert.match(gui, /sandbox = "unelevated"/);
  assert.match(cli, /sandbox = `"unelevated`"/);
});

test("downloadable mobile page uses one-use Bridge tickets", async () => {
  const mobile = await source("mobile-web/index.html");
  const embedded = await source("server-integration/desktop_connect.html");
  assert.equal(mobile, embedded);
  assert.match(mobile, /API_TICKET\s*=\s*"\/api\/desktop\/bridge\/ticket"/);
  assert.match(mobile, /new WebSocket\(wsUrl\(\),\["fluxgate-bridge","ticket\."\+ticket\]\)/);
  assert.match(mobile, /window\.FluxNative\.requestBridgeTicket\(callbackId\)/);
  assert.doesNotMatch(mobile, /bridge\/phone\?token=|data\.access_token/);
});
