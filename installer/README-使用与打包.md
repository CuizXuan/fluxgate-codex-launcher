# FluxGateAI Codex 安装器

GUI 与命令行安装器都使用独立目录：

```text
%APPDATA%\FluxGateAICodexLauncher\
|-- codex-home\
|-- codex-bin\
|-- companion\FluxGate-Codex-Companion.exe
|-- companion.json
|-- logs\
|-- FluxGateAI Codex.cmd
|-- FluxGateAI Codex 终端.cmd
`-- 卸载.cmd
```

安装器不会把 Codex Desktop 或 Codex CLI 二进制打进本仓库、EXE 或 GitHub Release。安装时从官方 `openai/codex` GitHub Releases 下载对应 Windows CLI，并固定放入专属 `codex-bin`，不复用或修改系统全局 CLI。

GUI EXE 内嵌 FluxGateAI 自有的原生托盘伴侣。账号登录会自动获得 `desktop-codex` 专用 Key，安装后伴侣直接后台连接，不需要 Node.js、Bridge ZIP 或终端窗口。

GUI 中的 Codex Desktop 复用选项默认关闭。用户主动启用时，只会在用户电脑上从已安装的官方 Desktop 创建本地副本；该副本不会上传或进入发布物。

## 隔离行为

- 只在启动脚本内设置独立 `CODEX_HOME`，不修改全局 PATH。
- 新版本不写入 `~/.codex`；检测到旧版本留下的标记配置时，只会恢复现有备份。
- API Key 写入独立 `codex-home/auth.json`。
- 伴侣只在运行时读取上述凭据，`companion.json` 不重复保存 Key。
- 开机启动快捷方式只启动原生伴侣；托盘菜单可切换项目目录和关闭自启动。
- 卸载脚本只删除本 Launcher 目录和快捷方式。

## 构建 EXE

在仓库根目录运行：

```powershell
.\build\build-release.ps1 -Version 2.1.1
```

生成的 EXE 嵌入 `FluxGate-Codex-Setup-GUI.ps1` 和本仓库编译的原生伴侣，不嵌入任何 OpenAI 文件。
