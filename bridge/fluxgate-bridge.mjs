#!/usr/bin/env node
/*
 * FluxGateAI Bridge — 桌面常驻客户端
 * ---------------------------------------------------------------------------
 * 把这台电脑注册到 FluxGate 网关的 Bridge，手机端 /connect 页面即可远程给
 * 本机的 Codex 发指令。执行用隔离的 CODEX_HOME（不影响官方 Codex）。
 *
 * 首次运行会引导登录 FluxGate 账号并保存配置到 fluxgate-bridge.config.json。
 * 运行：  node fluxgate-bridge.mjs
 * 依赖：  ws（见同目录 package.json）
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import readline from "node:readline";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import WebSocket from "ws";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = path.join(__dirname, "fluxgate-bridge.config.json");

// ===== 默认配置（分发前可改）=====
const DEFAULTS = {
  siteBaseUrl: "https://api.fluxapi.cloud",         // 网关根地址（含 /api/desktop/codex/login）
  codexHome: path.join(os.homedir(), "AppData", "Roaming", "FluxGateAICodexLauncher", "codex-home"),
  workdir: os.homedir(),                             // Codex 执行的工作目录
  execArgs: ["exec"],                                // codex 子命令与参数；如需自动执行可加 "--full-auto"
  codexBin: "codex",                                 // codex 可执行文件名或绝对路径
  maxRunMs: 10 * 60 * 1000                           // 单次执行超时（毫秒）
};

// ---------------------------------------------------------------------------
function log(...a) { console.log("[" + new Date().toISOString().slice(11, 19) + "]", ...a); }
function ask(q, opts = {}) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((res) => {
    if (opts.hidden) {
      const stdin = process.stdin;
      process.stdout.write(q);
      let buf = "";
      const onData = (data) => {
        const s = data.toString("utf8");
        for (const ch of s) {
          const code = ch.charCodeAt(0);
          if (code === 13 || code === 10) {           // Enter
            if (stdin.setRawMode) stdin.setRawMode(false);
            stdin.pause(); stdin.removeListener("data", onData);
            process.stdout.write("\n"); rl.close(); return res(buf);
          } else if (code === 3) {                     // Ctrl+C
            process.stdout.write("\n"); process.exit(1);
          } else if (code === 127 || code === 8) {     // Backspace
            buf = buf.slice(0, -1);
          } else if (code >= 32) {                     // printable
            buf += ch;
          }
        }
      };
      if (stdin.setRawMode) stdin.setRawMode(true);
      stdin.resume(); stdin.on("data", onData);
    } else {
      rl.question(q, (ans) => { rl.close(); res(ans.trim()); });
    }
  });
}

function loadConfig() {
  if (fs.existsSync(CONFIG_PATH)) {
    try { return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8")) }; }
    catch (e) { log("配置文件损坏，重新初始化:", e.message); }
  }
  return null;
}
function saveConfig(cfg) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2), "utf8");
  log("配置已保存:", CONFIG_PATH);
}

async function firstRunSetup() {
  console.log("\n=== FluxGateAI Bridge 首次设置 ===\n");
  const cfg = { ...DEFAULTS };
  const site = await ask("网关地址 [" + cfg.siteBaseUrl + "]: ");
  if (site) cfg.siteBaseUrl = site.replace(/\/+$/, "");
  const username = await ask("FluxGateAI 账号: ");
  const password = await ask("密码: ", { hidden: true });
  log("正在登录换取访问令牌...");
  const token = await login(cfg.siteBaseUrl, username, password);
  cfg.accessToken = token;
  const wd = await ask("Codex 工作目录 [" + cfg.workdir + "]: ");
  if (wd) cfg.workdir = wd;
  cfg.deviceId = crypto.randomUUID();
  cfg.deviceName = os.hostname();
  saveConfig(cfg);
  return cfg;
}

async function login(siteBaseUrl, username, password) {
  const r = await fetch(siteBaseUrl.replace(/\/+$/, "") + "/api/desktop/codex/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password })
  });
  const j = await r.json().catch(() => ({}));
  if (!j.success || !j.data || !j.data.access_token) {
    throw new Error("登录失败: " + (j.message || ("HTTP " + r.status)));
  }
  log("登录成功:", j.data.user && j.data.user.username);
  return j.data.access_token;
}

// Windows 下 npm 安装的 codex 是 codex.cmd 垫片，Node 的 spawn 不带 shell 时无法
// 直接启动 .cmd（ENOENT）。这里把 codexBin 解析成真正可 spawn 的目标：
// 优先 .exe；命中 npm 垫片时改用当前 Node 直接跑其内部 codex.js。
//
// 绝不使用 shell:true —— prompt 来自手机端，经 cmd.exe 解析等同于把远程输入
// 交给命令解释器（`&`、`|`、`%VAR%` 都会生效），构成远程命令执行。解析不出
// 可直接 spawn 的目标时宁可报错，让用户在配置里填 .exe 绝对路径。
function resolveCodexSpawn(bin, args) {
  if (process.platform !== "win32") return { file: bin, args };
  const candidates = [];
  if (bin.includes("\\") || bin.includes("/") || path.extname(bin)) {
    candidates.push(bin);
    if (!path.extname(bin)) { for (const ext of [".exe", ".cmd", ".bat"]) candidates.push(bin + ext); }
  } else {
    const dirs = (process.env.PATH || "").split(";").filter(Boolean);
    for (const ext of [".exe", ".cmd", ".bat"]) {
      for (const dir of dirs) candidates.push(path.join(dir, bin + ext));
    }
  }
  const found = candidates.find((p) => { try { return fs.existsSync(p); } catch { return false; } });
  if (!found) return { file: bin, args };
  const ext = path.extname(found).toLowerCase();
  if (ext !== ".cmd" && ext !== ".bat") return { file: found, args };
  const shimJs = path.join(path.dirname(found), "node_modules", "@openai", "codex", "bin", "codex.js");
  if (fs.existsSync(shimJs)) return { file: process.execPath, args: [shimJs, ...args] };
  throw new Error(
    `codexBin 指向批处理垫片 ${found}，但未在其旁找到 @openai/codex 的 codex.js。` +
    `请把配置文件里的 codexBin 改为 codex.exe 的绝对路径。`
  );
}

// ---------------------------------------------------------------------------
// WebSocket 设备连接 + 执行引擎
// ---------------------------------------------------------------------------
class Bridge {
  constructor(cfg) {
    this.cfg = cfg;
    this.ws = null;
    this.running = new Map(); // sessionId -> child process
    this.backoff = 1000;
  }

  wsUrl() {
    const u = new URL(this.cfg.siteBaseUrl);
    const proto = u.protocol === "https:" ? "wss:" : "ws:";
    const name = encodeURIComponent(this.cfg.deviceName || os.hostname());
    return `${proto}//${u.host}/api/desktop/bridge/device?token=${encodeURIComponent(this.cfg.accessToken)}&device_id=${encodeURIComponent(this.cfg.deviceId)}&device_name=${name}`;
  }

  connect() {
    log("连接网关 Bridge...");
    const ws = new WebSocket(this.wsUrl());
    this.ws = ws;
    ws.on("open", () => {
      this.backoff = 1000;
      log("已注册为设备:", this.cfg.deviceName, "(" + this.cfg.deviceId.slice(0, 8) + ")");
      log("手机端打开  " + this.cfg.siteBaseUrl + "/api/desktop/connect  即可远程使用");
    });
    ws.on("message", (raw) => {
      let m; try { m = JSON.parse(raw.toString()); } catch { return; }
      this.onMessage(m);
    });
    ws.on("close", (code) => {
      log("连接断开 (code " + code + ")");
      if (code === 4001 || code === 1008) { log("认证失败：请删除配置文件后重新登录"); }
      this.reconnect();
    });
    ws.on("error", (e) => { log("连接错误:", e.message); });
  }

  reconnect() {
    for (const [sid, child] of this.running) { try { child.kill(); } catch {} this.running.delete(sid); }
    const wait = Math.min(this.backoff, 30000);
    log("将在", Math.round(wait / 1000) + "s 后重连");
    setTimeout(() => { this.backoff = Math.min(this.backoff * 2, 30000); this.connect(); }, wait);
  }

  sendFrame(obj) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      try { this.ws.send(JSON.stringify(obj)); } catch {}
    }
  }

  onMessage(m) {
    if (m.type === "exec") return this.runExec(m);
    if (m.type === "cancel") return this.cancel(m.session_id);
    if (m.type === "registered") return; // ack
  }

  runExec(m) {
    const sid = m.session_id;
    const prompt = (m.prompt || "").trim();
    if (!sid || !prompt) return;
    if (this.running.has(sid)) { this.sendFrame({ type: "error", session_id: sid, message: "该会话已有任务在执行" }); return; }

    const cwd = fs.existsSync(this.cfg.workdir) ? this.cfg.workdir : os.homedir();
    const args = [...this.cfg.execArgs, prompt];
    log("执行 [" + sid.slice(0, 8) + "]:", prompt.slice(0, 60).replace(/\n/g, " "));

    let child;
    try {
      const target = resolveCodexSpawn(this.cfg.codexBin, args);
      child = spawn(target.file, target.args, {
        cwd,
        env: { ...process.env, CODEX_HOME: this.cfg.codexHome },
        windowsHide: true
      });
    } catch (e) {
      this.sendFrame({ type: "error", session_id: sid, message: "无法启动 codex: " + e.message });
      return;
    }
    this.running.set(sid, child);

    // 输出批量合并，降低帧率（每 60ms 或 2KB flush 一次）
    let buf = ""; let flushTimer = null;
    const flush = () => {
      if (buf) { this.sendFrame({ type: "output", session_id: sid, data: buf, stream: "stdout" }); buf = ""; }
      flushTimer = null;
    };
    const push = (chunk) => {
      buf += chunk;
      if (buf.length >= 2048) { if (flushTimer) { clearTimeout(flushTimer); } flush(); }
      else if (!flushTimer) { flushTimer = setTimeout(flush, 60); }
    };
    // setEncoding 让 Node 在多字节字符边界处切分；直接 buf.toString() 会把一个
    // UTF-8 汉字劈到两个 chunk 里，手机端就看到乱码。
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", push);
    child.stderr.on("data", push);

    const killTimer = setTimeout(() => {
      log("会话超时，终止:", sid.slice(0, 8));
      killTree(child);
    }, this.cfg.maxRunMs);

    child.on("close", (code) => {
      clearTimeout(killTimer);
      if (flushTimer) { clearTimeout(flushTimer); }
      flush();
      this.running.delete(sid);
      this.sendFrame({ type: "done", session_id: sid, exit_code: code == null ? -1 : code });
      log("完成 [" + sid.slice(0, 8) + "] 退出码", code);
    });
    child.on("error", (e) => {
      clearTimeout(killTimer);
      this.running.delete(sid);
      this.sendFrame({ type: "error", session_id: sid, message: "codex 执行失败: " + e.message });
    });
  }

  cancel(sid) {
    const child = this.running.get(sid);
    if (child) { log("取消会话:", sid.slice(0, 8)); killTree(child); }
  }
}

// Windows 上 child.kill() 只终止直接子进程。codex 走 npm 垫片时直接子进程是
// node，真正干活的原生 codex 会活下来继续改文件——取消和超时都必须连整棵树一起杀。
function killTree(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) return;
  if (process.platform === "win32" && child.pid) {
    try {
      spawn("taskkill", ["/pid", String(child.pid), "/T", "/F"], { windowsHide: true, stdio: "ignore" });
      return;
    } catch { /* taskkill 不可用时回退到下面的 kill */ }
  }
  try { child.kill("SIGKILL"); } catch {}
}

// ---------------------------------------------------------------------------
(async function main() {
  let cfg = loadConfig();
  if (!cfg || !cfg.accessToken || !cfg.deviceId) {
    cfg = await firstRunSetup();
  }
  if (!fs.existsSync(cfg.codexHome)) {
    log("⚠ 未找到隔离 CODEX_HOME:", cfg.codexHome);
    log("  请先用 FluxGate Codex 一键安装器完成安装，或在配置文件中修正 codexHome");
  }
  const bridge = new Bridge(cfg);
  bridge.connect();
  process.on("SIGINT", () => { log("退出"); process.exit(0); });
})().catch((e) => { log("启动失败:", e.message); process.exit(1); });
