# FluxGate Codex Launcher

FluxGate Codex Launcher is a community-maintained Windows installer and remote Bridge for connecting OpenAI Codex CLI to a FluxGateAI gateway. It is not an official OpenAI Codex product and is not endorsed by OpenAI. This repository and its release artifacts are distributed without charge and are not offered for secondary commercialization.

## Downloads

Stable files are published only through [GitHub Releases](https://github.com/CuizXuan/fluxgate-codex-launcher/releases/latest).

- `FluxGate-Codex-Launcher_<version>.exe`: graphical Windows installer.
- `FluxGate-Codex-Setup-GUI.ps1`: auditable GUI installer source.
- `FluxGate-Codex-Setup.ps1`: command-line installer.
- `Install-FluxGate-Codex*.bat`: double-click entry points.
- `FluxGate-Codex-Bridge_<version>.zip`: desktop Bridge source and launcher.
- `FluxGate-Codex-Mobile-Web_<version>.zip`: self-contained mobile web source.

No release asset contains Codex Desktop, Codex CLI, `app.asar`, or any other OpenAI binary. During installation the scripts reuse a Codex CLI already on the user's machine, install `@openai/codex` from npm, or download the CLI from the official `openai/codex` GitHub Releases. The optional Desktop mode only copies an already-installed Codex Desktop locally after explicit user selection; it is disabled by default and never enters this repository or its Releases.

## Source layout

- `installer/`: GUI and command-line Windows installers.
- `src/`: small C# bootstrapper that embeds the GUI PowerShell script in the EXE.
- `bridge/`: Node.js desktop Bridge that runs the user's Codex CLI and connects to the gateway over WSS.
- `mobile-web/`: self-contained phone client served by the gateway.
- `server-integration/`: FluxGateAI/new-api controller integration sources and setup notes.
- `build/`: deterministic release builder used locally and by GitHub Actions.

## Build

Requirements: Windows PowerShell 5.1, the inbox .NET Framework C# compiler, and Node.js.

```powershell
.\build\build-release.ps1 -Version 2.0.1
```

The build validates PowerShell and Bridge syntax, compiles the EXE, runs its embedded-resource self-test, and creates Bridge/mobile ZIP assets. The EXE is a transparent launcher for the included GUI PowerShell script; it is not an archive of Codex itself.

## Attribution and license

The server integration is designed for FluxGateAI/new-api and retains the applicable new-api, QuantumNous, author, license and NOTICE material. See [LICENSE](LICENSE), [NOTICE](NOTICE), [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md), and `server-integration/README.md`.
