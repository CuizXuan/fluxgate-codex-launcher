# FluxGate Codex Launcher

FluxGate Codex Launcher is a community-maintained Windows installer and remote Bridge for connecting OpenAI Codex CLI to a FluxGateAI gateway. It is not an official OpenAI Codex product and is not endorsed by OpenAI. This repository and its release artifacts are distributed without charge and are not offered for secondary commercialization.

## Beginner flow

1. Download and run `FluxGate-Codex-Launcher_<version>.exe`.
2. Sign in with a FluxGateAI account and choose the project folder.
3. Installation opens a ready-to-use Codex CLI terminal, starts the native Bridge companion in the Windows tray, and enables companion startup by default.
4. Open the FluxAI Android app and tap `远程`; the saved account credential is exchanged for one-use Bridge tickets automatically.

No Node.js, Bridge ZIP, terminal window, browser login, or second desktop credential is required in this flow.

## Downloads

Stable files are published only through [GitHub Releases](https://github.com/CuizXuan/fluxgate-codex-launcher/releases/latest).

- `FluxGate-Codex-Launcher_<version>.exe`: recommended all-in-one graphical installer with the native tray companion embedded.
- `FluxGate-Codex-Setup-GUI.ps1`: auditable GUI installer source.
- `FluxGate-Codex-Setup.ps1`: command-line installer.
- `Install-FluxGate-Codex*.bat`: double-click entry points.
- `FluxGate-Codex-Bridge_<version>.zip`: legacy Node.js Bridge for advanced/manual deployments.
- `FluxGate-Codex-Mobile-Web_<version>.zip`: self-contained mobile web source for advanced/self-hosted deployments.

No release asset contains Codex Desktop, Codex CLI, `app.asar`, or any other OpenAI binary. During installation the Launcher downloads the official standalone Codex CLI into its own `%APPDATA%\FluxGateAICodexLauncher\codex-bin` directory. It does not reuse, update, or uninstall the user's global Codex CLI. The optional Desktop mode only copies an already-installed Codex Desktop locally after explicit user selection; it is disabled by default and never enters this repository or its Releases.

## Source layout

- `installer/`: GUI and command-line Windows installers.
- `src/`: small C# bootstrapper that embeds the GUI PowerShell script in the EXE.
- `src/Companion.cs`: native Windows tray companion embedded in the Launcher.
- `bridge/`: legacy Node.js Bridge retained for advanced/manual deployments.
- `mobile-web/`: self-contained phone client served by the gateway.
- `server-integration/`: FluxGateAI/new-api controller integration sources and setup notes.
- `build/`: deterministic release builder used locally and by GitHub Actions.

## Build

Requirements: Windows PowerShell 5.1, the inbox .NET Framework C# compiler, and Node.js.

```powershell
.\build\build-release.ps1 -Version 2.1.1
```

The build validates PowerShell and Bridge syntax, compiles and integration-tests the native companion, embeds it with the GUI installer, runs resource self-tests, and creates the advanced Bridge/mobile ZIP assets. The EXE contains FluxGateAI installer/companion code only; it is not an archive of Codex itself.

## Attribution and license

The server integration is designed for FluxGateAI/new-api and retains the applicable new-api, QuantumNous, author, license and NOTICE material. See [LICENSE](LICENSE), [NOTICE](NOTICE), [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md), and `server-integration/README.md`.
