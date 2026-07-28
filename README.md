# FluxGate Codex Launcher

FluxGate Codex Launcher is a community-maintained Windows installer and remote Bridge for connecting OpenAI Codex CLI to a FluxGateAI gateway. It is not an official OpenAI Codex product and is not endorsed by OpenAI. This repository and its release artifacts are distributed without charge and are not offered for secondary commercialization.

## Beginner flow

1. Download and run `FluxGate-Codex-Full_<version>.exe`.
2. Sign in with a FluxGateAI account and choose the project folder.
3. Installation sets up the bundled Codex CLI, installs or detects official Codex Desktop through Microsoft Store, opens both desktop and terminal surfaces, starts the native Bridge companion, and enables companion startup by default.
4. Open the FluxAI Android app and tap `远程`; the saved account credential is exchanged for one-use Bridge tickets automatically.

No Node.js, Bridge ZIP, manual terminal setup, browser login, or second FluxGateAI credential is required in this flow.

## Downloads

Stable files are published only through [GitHub Releases](https://github.com/CuizXuan/fluxgate-codex-launcher/releases/latest).

- `FluxGate-Codex-Full_<version>.exe`: recommended x64 package with the official Apache-2.0 Codex CLI archive, graphical installer, and native tray companion embedded.
- `FluxGate-Codex-Launcher_<version>.exe`: smaller online installer that downloads the same official Codex CLI during setup.
- `FluxGate-Codex-Setup-GUI.ps1`: auditable GUI installer source.
- `FluxGate-Codex-Setup.ps1`: command-line installer.
- `Install-FluxGate-Codex*.bat`: double-click entry points.
- `FluxGate-Codex-Bridge_<version>.zip`: legacy Node.js Bridge for advanced/manual deployments.
- `FluxGate-Codex-Mobile-Web_<version>.zip`: self-contained mobile web source for advanced/self-hosted deployments.

The Full package embeds the official Apache-2.0 Codex CLI ZIP from `openai/codex`; the online package downloads that same signed release asset during installation. Both install it into `%APPDATA%\FluxGateAICodexLauncher\codex-bin` and do not reuse, update, or uninstall the user's global Codex CLI. The Launcher also installs its bundled `NOTICE` and third-party license file beside the isolated runtime. Official Codex Desktop remains a Microsoft Store package and is installed/detected through product ID `9PLM9XGG6VKS`; its 1.95 GB Store payload, license, and `app.asar` are not repackaged. Launcher starts it with an isolated profile and `CODEX_HOME` connected to FluxGateAI.

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
.\build\build-release.ps1 -Version 2.2.0 -BuildFull
```

The build validates PowerShell and Bridge syntax, compiles and integration-tests the native companion, builds the online Launcher, downloads and verifies the official x64 Codex CLI ZIP for the Full Launcher, runs resource self-tests, and creates the advanced Bridge/mobile ZIP assets.

## Attribution and license

The server integration is designed for FluxGateAI/new-api and retains the applicable new-api, QuantumNous, author, license and NOTICE material. See [LICENSE](LICENSE), [NOTICE](NOTICE), [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md), and `server-integration/README.md`.
