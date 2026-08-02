# FluxGateAI Codex 安装器

GUI 与命令行安装器都使用独立目录：

```text
%APPDATA%\FluxGateAICodexLauncher\
|-- codex-home\
|-- codex-bin\
|-- desktop-app\                         # 可选的内置便携桌面版
|-- desktop-data\                        # 每台机器独立创建
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

GUI 提供三种桌面模式：使用安装包内置便携版、使用本机官方版、仅安装 Codex 终端。普通 Full EXE 不包含 Desktop，会检测并通过 Microsoft Store 产品 ID `9PLM9XGG6VKS` 安装官方版本；可选的 `Desktop-Portable` EXE 则包含构建者显式提供的 `app` 目录快照，安装后不注册商店、不自动更新。两种桌面来源都使用独立浏览器数据目录和 `CODEX_HOME`，并在启动前恢复安装时选定的模型。

便携载荷只允许包含应用程序文件。构建器不会读取或打包 `%LOCALAPPDATA%\Packages\OpenAI.Codex_*`、`%APPDATA%\FluxGateAICodexLauncher`、`auth.json`、Cookie、浏览器资料或 API Key。每台目标电脑都必须使用自己的 FluxGateAI 账号或 Key 完成初始化。

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
.\build\build-release.ps1 -Version 2.3.0 -BuildFull
```

构建会生成小型在线 Launcher 和内嵌官方 Codex CLI ZIP 的 Full Launcher。普通 Full 仍不包含 Codex Desktop。

使用本机最新安装的 `OpenAI.Codex` 生成便携桌面版：

```powershell
.\build\build-release.ps1 -Version 2.3.0 -BuildPortableDesktop
```

也可以显式指定已经提取的应用目录：

```powershell
.\build\build-release.ps1 -Version 2.3.0 -BuildPortableDesktop `
  -PortableDesktopDir 'C:\path\to\OpenAI.Codex\app'
```

输出包括 `FluxGate-Codex-Desktop-Portable_2.3.0.exe` 和同名 JSON 构建清单。便携版在 Full 的基础上追加经过 SHA-256 校验的 ZIP，要求 x64 目录中存在 `ChatGPT.exe`、`resources\app.asar` 和 `resources\codex.exe`；最终文件达到 GitHub Release 单文件 2 GB 上限时构建会直接失败。
