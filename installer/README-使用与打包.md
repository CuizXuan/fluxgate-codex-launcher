# FluxGateAI Codex 安装器

GUI 与命令行安装器都使用独立目录：

```text
%APPDATA%\FluxGateAICodexLauncher\
|-- codex-home\
|-- codex-bin\
|-- logs\
|-- FluxGateAI Codex.cmd
|-- FluxGateAI Codex 终端.cmd
`-- 卸载.cmd
```

安装器不会把 Codex Desktop 或 Codex CLI 二进制打进本仓库、EXE 或 GitHub Release。安装时按以下顺序获取 CLI：

1. 复用系统中已经安装的 `codex`。
2. 通过官方 npm 包 `@openai/codex` 安装。
3. 从官方 `openai/codex` GitHub Releases 下载对应 Windows CLI。

GUI 中的 Codex Desktop 复用选项默认关闭。用户主动启用时，只会在用户电脑上从已安装的官方 Desktop 创建本地副本；该副本不会上传或进入发布物。

## 隔离行为

- 只在启动脚本内设置独立 `CODEX_HOME`，不修改全局 PATH。
- 新版本不写入 `~/.codex`；检测到旧版本留下的标记配置时，只会恢复现有备份。
- API Key 写入独立 `codex-home/auth.json`。
- 卸载脚本只删除本 Launcher 目录和快捷方式。

## 构建 EXE

在仓库根目录运行：

```powershell
.\build\build-release.ps1 -Version 2.0.0
```

生成的 EXE 只嵌入 `FluxGate-Codex-Setup-GUI.ps1`，不嵌入任何 OpenAI 文件。
