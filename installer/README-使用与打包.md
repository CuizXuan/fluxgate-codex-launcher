# FluxGateAI Codex 安装器

GUI 与命令行安装器都使用独立目录：

```text
%APPDATA%\FluxGateAICodexLauncher\
|-- codex-home\
|-- codex-bin\
|-- companion\FluxGate-Codex-Companion.exe
|-- companion.json
|-- logs\
|-- FluxGateAI Codex Desktop.cmd
|-- Launch-FluxGate-Codex-Desktop.ps1
|-- FluxGateAI Codex 终端.cmd
`-- 卸载.cmd
```

Full EXE 内嵌从官方 `openai/codex` Release 下载并校验的 Apache-2.0 Codex CLI ZIP；在线 EXE 安装时下载同一资产。两者都固定安装到专属 `codex-bin`，不复用或修改系统全局 CLI。

GUI EXE 内嵌 FluxGateAI 自有的原生托盘伴侣。账号登录会自动获得 `desktop-codex` 专用 Key，安装后伴侣直接后台连接，不需要 Node.js、Bridge ZIP 或终端窗口。

GUI 默认检测并通过 Microsoft Store 产品 ID `9PLM9XGG6VKS` 安装官方 Codex Desktop。Store 包本身不被复制或重新发布；Launcher 生成隔离启动器，使用独立浏览器数据目录和 `CODEX_HOME`，并在启动前恢复安装时选定的模型。

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
.\build\build-release.ps1 -Version 2.2.0 -BuildFull
```

构建会生成小型在线 Launcher 和内嵌官方 Codex CLI ZIP 的 Full Launcher。Codex Desktop 仍由 Microsoft Store 安装，不进入任一 EXE。
