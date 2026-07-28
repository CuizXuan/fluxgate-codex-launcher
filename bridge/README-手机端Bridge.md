# 手机端 Connect Bridge — 高级手动部署

> 普通用户不再需要本目录。`v2.1.0` 起，运行 `FluxGate-Codex-Launcher_<version>.exe` 会安装并启动原生 Windows 托盘伴侣；手机直接在 FluxAI APK 中点“远程”。本目录保留为 Node.js 兼容实现和自托管参考。

对标 `codex.jbbt.cc/connect`：手机浏览器远程给你电脑上的 Codex 发指令。JBB 那句安全说明"消息通过 HTTPS 传输并按账号与设备隔离；Bridge 不读取 Codex/OpenAI 登录凭证"——这套实现逐条对齐。

## 架构

```
 手机浏览器  https://api.fluxapi.cloud/api/desktop/connect
     │  账号密码登录或专用 API Key → POST /api/desktop/bridge/ticket
     │  WSS  /api/desktop/bridge/phone（一次性 ticket 子协议）
     ▼
 FluxGate 网关内的 Bridge Hub（内存中转，按 user_id 严格隔离）
     ▲
     │  WSS  /api/desktop/bridge/device（Authorization: Bearer <desktop-codex API Key>）
 桌面 Bridge 客户端（fluxgate-bridge.mjs）
     │  收到 prompt → 用隔离 CODEX_HOME 跑  codex exec  → 流式回传 stdout
     ▼
 你电脑上的 Codex（阶段1/2 装的 FluxGate 版，独立配置）
```

Hub 只转发 JSON 帧，不落任何 Codex/OpenAI 凭证；一个手机账号只能看到、只能连到**同一 user_id 下**注册的设备（后端 `routePrompt` 里强校验 `devices[phone.userID][deviceID]`）。

## 三个组成部分

**1. 后端（已写入你的项目，重编译即生效）**

- `controller/desktop_bridge.go` — Bridge Hub + 两个 WS 端点 + `/connect` 页面服务（`go:embed`）
- `controller/desktop_connect.html` — 自包含移动端页面（被上面的 go:embed 内嵌）
- `router/api-router.go` — 新增路由：
  - `GET /api/desktop/bridge/device`、`/phone`（挂在引擎根，**绕开 gzip**，否则 WS 升级会被 gzip 包装的 ResponseWriter 破坏）
  - `POST /api/desktop/bridge/ticket`（专用 API Key 换取 60 秒、单次使用的手机 WSS 票据）
  - `GET /api/desktop/connect`（手机页面，走 gzip 无妨）

WS 帧协议（JSON）：
```
手机→Hub： {type:"list_devices"} | {type:"prompt", device_id, session_id, prompt, cwd?} | {type:"cancel", session_id}
Hub→手机： {type:"devices", devices:[{device_id,device_name,online}]} | {type:"output",session_id,data} | {type:"done",session_id,exit_code} | {type:"error"/"device_offline",...}
设备→Hub： {type:"output",session_id,data} | {type:"done",session_id,exit_code} | {type:"error",...}
Hub→设备： {type:"exec",session_id,prompt,cwd} | {type:"cancel",session_id}
```
鉴权：桌面端 WSS 使用 `Authorization: Bearer <desktop-codex API Key>`；手机页先用同一专用 Key 换取一次性 ticket，再通过 `Sec-WebSocket-Protocol: fluxgate-bridge, ticket.<ticket>` 建连。完整 API Key 不进入 URL 或代理访问日志。含 50s 心跳 ping、断连自动清理会话与设备并广播。

**2. 桌面 Bridge 客户端（Node）**

- `fluxgate-bridge.mjs` — 主程序
- `package.json` — 依赖 `ws`
- `启动 FluxGate Bridge.bat` — 检测 Node → 首次自动 `npm install`（失败切 npmmirror 镜像）→ 运行

首次运行引导登录 FluxGate 账号换取名为 `desktop-codex` 的专用 API Key，保存到 `fluxgate-bridge.config.json`；旧版 access token 配置会被拒绝并要求重新登录。device_id 自动生成并持久化，device_name 取主机名。执行用隔离 `CODEX_HOME`（默认指向阶段2 的 `%APPDATA%\FluxGateAICodexLauncher\codex-home`），**不碰官方 Codex**。

**3. 手机页面**：深色移动端，登录→设备列表→聊天，流式显示 Codex 输出，支持停止、断线自动重连、令牌失效自动回登录页、localStorage 记住登录。

## 推荐流程

1. Windows 只安装 Launcher EXE，账号登录并选择项目目录。
2. 确认右下角存在 `FluxGateAI Codex` 托盘图标。
3. 手机 FluxAI 使用同一账号登录后点“远程”。

## 手动部署步骤

1. **后端**：重新 `go build` 并重启网关。验证：浏览器开 `https://api.fluxapi.cloud/api/desktop/connect` 应看到登录页。
2. **电脑端**（每台要远程的电脑各跑一次）：
   - 装 Node.js 18+（多数人装 codex 时已装）。
   - 把 `fluxgate-bridge` 整个文件夹拷到电脑，双击 `启动 FluxGate Bridge.bat`。
   - 首次输入 FluxGate 账号密码 + 工作目录（Codex 在哪个项目跑）。保持这个窗口开着。
3. **手机**：浏览器打开 `https://api.fluxapi.cloud/api/desktop/connect`，同一个账号登录 → 看到你的电脑 → 点进去发指令。

## 已验证（2026-07-26 真机实测）

在本机起隔离网关（真实 `go build` 产物，独立端口 13210 + 独立 SQLite）跑完整链路：

- **后端**：整包真机 `go build` 通过；`/api/desktop/connect` 返回页面，两个 WS 端点正常升级。
- **端到端**：真实 Bridge 客户端 + 假手机 → 「注册设备 → 下发 exec → 隔离 `CODEX_HOME` 执行 → 批量流式回传 → `done` 带退出码 0」全程正确；含引号与换行的提示词原样送达，未被 shell 解释。
- **真实 codex**：把 `codexBin` 设为裸名 `codex` 时，成功拉起本机 npm 装的 `codex-cli 0.142.4`，且其自报的 `codex_home` 就是隔离目录 —— 证明不碰官方 `~/.codex`。
- **手机页面**：真实浏览器（移动视口）完整走通登录 → 设备列表 → 发指令 → 流式输出渲染。
- **账号隔离**：坏 token 在 WS 升级前被 401 拒绝；另一个账号连上来看到的设备列表为空，而本账号能看到在线设备。

### 修复的 Windows 专属问题

首版在 Windows 上**根本起不来 codex**：npm 安装的 `codex` 是 `codex.cmd` 批处理垫片，Node 的 `spawn()` 不带 shell 时无法执行 `.cmd`，直接 `ENOENT`。

现已在 `fluxgate-bridge.mjs` 增加 `resolveCodexSpawn()`：优先找 `.exe`；命中 npm 垫片时改用当前 Node 直接执行垫片内部的 `codex.js`，参数原样传递不经 `cmd.exe`（否则提示词里的引号、换行、`%VAR%` 会被批处理解释器破坏）；非 npm 的 `.cmd`/`.bat` 才回退到 `shell:true`。

## 执行行为说明（重要）

默认 `execArgs: ["exec"]`，即 `codex exec <你的指令>`。这是 Codex 的非交互模式。如果你希望 Codex 能自动改文件/执行命令而不停下来等确认，在 `fluxgate-bridge.config.json` 把 `execArgs` 改为如 `["exec","--full-auto"]`（具体标志以你的 codex 版本 `codex exec --help` 为准）。单次执行默认 10 分钟超时。

## 后续增强方向（非必须）

- 迁移到 Codex `app-server` 持久会话协议，替代每条消息独立的 `codex exec`。
- 会话上下文延续（当前每条 prompt 是一次独立 `codex exec`）：改用 codex 会话 resume 或 `codex proto` 长连接。
- 端到端加密（当前与 JBB 同为"传输加密 + 账号设备隔离"，非 E2EE）。
- 后端把在线设备落库，支持离线设备列表与最近使用时间。
