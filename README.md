# FluxGate Codex Launcher

FluxGate Codex Launcher is a community-maintained Windows installer and remote Bridge for connecting OpenAI Codex CLI to a FluxGateAI gateway. It is not an official OpenAI Codex product and is not endorsed by OpenAI. This repository and its release artifacts are distributed without charge and are not offered for secondary commercialization.

## Beginner flow

1. Download and run `FluxGate-Codex-Full_<version>.exe`, or use the explicitly labeled `FluxGate-Codex-Desktop-Portable_<version>.exe` when a fixed offline Desktop snapshot is attached to the release.
2. Sign in with a FluxGateAI account and choose the project folder.
3. Installation sets up the bundled Codex CLI, installs or detects official Codex Desktop through Microsoft Store, opens both desktop and terminal surfaces, starts the native Bridge companion, and enables companion startup by default.
4. Open the FluxAI Android app and tap `远程`; the saved account credential is exchanged for one-use Bridge tickets automatically.

No Node.js, Bridge ZIP, manual terminal setup, browser login, or second FluxGateAI credential is required in this flow.

## Downloads

Stable files are published only through [GitHub Releases](https://github.com/CuizXuan/fluxgate-codex-launcher/releases/latest).

- `FluxGate-Codex-Full_<version>.exe`: recommended x64 package with the official Apache-2.0 Codex CLI archive, graphical installer, and native tray companion embedded.
- `FluxGate-Codex-Desktop-Portable_<version>.exe`: optional x64 offline edition containing everything in Full plus a locally supplied Codex Desktop `app` snapshot. It is produced outside GitHub Actions and is present only when the release publisher uploads it explicitly.
- `FluxGate-Codex-Desktop-Portable_<version>.json`: build manifest for the optional offline edition, including source version, sizes, update policy and SHA-256 hashes.
- `FluxGate-Codex-Launcher_<version>.exe`: smaller online installer that downloads the same official Codex CLI during setup.
- `FluxGate-Codex-Setup-GUI.ps1`: auditable GUI installer source.
- `FluxGate-Codex-Setup.ps1`: command-line installer.
- `Install-FluxGate-Codex*.bat`: double-click entry points.
- `FluxGate-Codex-Bridge_<version>.zip`: legacy Node.js Bridge for advanced/manual deployments.
- `FluxGate-Codex-Mobile-Web_<version>.zip`: self-contained mobile web source for advanced/self-hosted deployments.

The Full package embeds the official Apache-2.0 Codex CLI ZIP from `openai/codex`; the online package downloads that same signed release asset during installation. Both install it into `%APPDATA%\FluxGateAICodexLauncher\codex-bin` and do not reuse, update, or uninstall the user's global Codex CLI. The Launcher also installs its bundled `NOTICE` and third-party license file beside the isolated runtime. Full does **not** contain Codex Desktop. It installs or detects the Microsoft Store product `9PLM9XGG6VKS` and starts that package with an isolated profile and `CODEX_HOME` connected to FluxGateAI.

## Codex Desktop choices

The installer presents three explicit Desktop modes:

| Mode | Desktop source | Network requirement | Updates |
| --- | --- | --- | --- |
| Built-in portable copy | `desktop-app` snapshot appended to the optional Portable EXE | None during installation | Fixed version; replace by installing a newer Portable release |
| Locally installed official copy | Existing `OpenAI.Codex` package, with Microsoft Store offered when absent | Store access when not already installed | Managed by the user's official installation |
| Terminal only | No Desktop | None when using Full | Codex CLI only |

The Portable edition extracts its Desktop files to `%APPDATA%\FluxGateAICodexLauncher\desktop-app`. It does not register a Microsoft Store package and does not implement an updater. Users may keep that fixed snapshot, install a newer Portable release later, or install the official Desktop separately and rerun the Launcher in official mode.

Portable builds include application binaries only. They never read or package `%LOCALAPPDATA%\Packages\OpenAI.Codex_*`, `%APPDATA%\FluxGateAICodexLauncher`, `CODEX_HOME`, `auth.json`, browser profiles, cookies, API keys or other user data. Every target machine creates its own isolated `codex-home` and `desktop-data` directories and signs in to FluxGateAI independently.

The repository and GitHub Actions workflow do not contain or fetch the Portable Desktop payload. A release publisher must supply the local `app` directory explicitly and is responsible for the supplied third-party application files and their distribution terms. The generated JSON manifest records the source package/version and verifies both the appended ZIP and final EXE with SHA-256.

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
.\build\build-release.ps1 -Version 2.3.0 -BuildFull
```

The build validates PowerShell and Bridge syntax, compiles and integration-tests the native companion, builds the online Launcher, downloads and verifies the official x64 Codex CLI ZIP for the Full Launcher, runs resource self-tests, and creates the advanced Bridge/mobile ZIP assets.

To build the optional offline Desktop edition from the newest locally installed `OpenAI.Codex` package:

```powershell
.\build\build-release.ps1 -Version 2.3.0 -BuildPortableDesktop
```

To use a specific extracted application directory instead:

```powershell
.\build\build-release.ps1 -Version 2.3.0 -BuildPortableDesktop `
  -PortableDesktopDir 'C:\path\to\OpenAI.Codex\app'
```

`-BuildPortableDesktop` implies `-BuildFull`. The builder requires `ChatGPT.exe`, `resources\app.asar` and `resources\codex.exe`, rejects reparse points and user-data filenames, appends the verified ZIP outside the managed PE resource table, and fails before publication if the final artifact reaches GitHub's 2 GB per-file limit. Validate and upload the paired files together:

```powershell
.\release-assets\FluxGate-Codex-Desktop-Portable_2.3.0.exe --self-test-portable
gh release upload v2.3.0 `
  .\release-assets\FluxGate-Codex-Desktop-Portable_2.3.0.exe `
  .\release-assets\FluxGate-Codex-Desktop-Portable_2.3.0.json
```

## Attribution and license

The server integration is designed for FluxGateAI/new-api and retains the applicable new-api, QuantumNous, author, license and NOTICE material. See [LICENSE](LICENSE), [NOTICE](NOTICE), [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md), and `server-integration/README.md`.
