import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

async function source(path) {
  return readFile(join(root, path), "utf8");
}

test("launcher consumes the production dedicated-key login response", async () => {
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");
  assert.match(gui, /loginResp\.data\.api_key/);
  assert.doesNotMatch(gui, /desktop\/codex\/token|loginResp\.data\.access_token/);
  assert.match(gui, /\$DefaultModel\s+=\s+'gpt-5\.4-mini'/);
  assert.match(gui, /\$GatewayBaseUrl\s+=\s+'https:\/\/api\.fluxapi\.cloud\/v1'/);
});

test("desktop Bridge uses a dedicated API key header", async () => {
  const bridge = await source("bridge/fluxgate-bridge.mjs");
  assert.match(bridge, /j\.data\.api_key/);
  assert.match(bridge, /Authorization: `Bearer \$\{this\.cfg\.apiKey\}`/);
  assert.doesNotMatch(bridge, /bridge\/device\?token=|j\.data\.access_token/);
});

test("Launcher embeds the native background companion and reuses isolated credentials", async () => {
  const bootstrapper = await source("src/LauncherBootstrapper.cs");
  const companion = await source("src/Companion.cs");
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");

  assert.match(bootstrapper, /FluxGate\.CodexLauncher\.Companion/);
  assert.match(bootstrapper, /FLUXGATE_COMPANION_SOURCE/);
  assert.match(companion, /Path\.Combine\(config\.CodexHome, "auth\.json"\)/);
  assert.match(companion, /SetRequestHeader\("Authorization", "Bearer " \+ apiKey\)/);
  assert.match(companion, /exec --skip-git-repo-check -s workspace-write -/);
  assert.doesNotMatch(companion, /Log\([^\n]*prompt/);
  assert.match(gui, /FluxGate-Codex-Companion\.exe/);
  assert.match(gui, /FluxGateAI Codex Companion\.lnk/);
  assert.match(gui, /api\/desktop\/bridge\/ticket/);
  assert.match(gui, /desktop-codex 的专用 API Key/);
  assert.doesNotMatch(gui, /companionConfig[\s\S]{0,500}ApiKey\s*=/);
});

test("installers use a dedicated Codex binary instead of the global CLI", async () => {
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");
  const cli = await source("installer/FluxGate-Codex-Setup.ps1");

  assert.match(gui, /Join-Path \$binDir 'codex\.exe'/);
  assert.match(cli, /Join-Path \$InstallDir 'codex\.exe'/);
  assert.doesNotMatch(gui, /npm install -g|Get-Command codex/);
  assert.doesNotMatch(cli, /npm install -g|Get-Command codex/);
  assert.match(gui, /sandbox = "unelevated"/);
  assert.match(cli, /sandbox = `"unelevated`"/);
  assert.match(gui, /\$assetName = 'codex-' \+ \$arch \+ '-msvc\.exe\.zip'/);
  assert.match(cli, /\$assetName = 'codex-' \+ \$arch \+ '-msvc\.exe\.zip'/);
  assert.match(gui, /Where-Object \{ \$_.name -eq \$assetName \}/);
  assert.match(cli, /Where-Object \{ \$_.name -eq \$assetName \}/);
  assert.doesNotMatch(gui, /Where-Object \{ \$_.name -match \$arch/);
  assert.doesNotMatch(cli, /Where-Object \{ \$_.name -match \$arch/);
  assert.match(gui, /Move-Item[^\n]+\$mainName[^\n]+\$localCli/);
  assert.match(cli, /Move-Item[^\n]+\$mainName[^\n]+'codex\.exe'/);
  assert.match(gui, /installedVersion -notmatch '\^codex-cli\\s'/);
  assert.match(cli, /installedVersion -notmatch '\^codex-cli\\s'/);
});

test("GUI installation opens the local Codex terminal", async () => {
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");
  const cli = await source("installer/FluxGate-Codex-Setup.ps1");

  assert.match(gui, /Content="打开 Codex 终端"/);
  assert.match(gui, /\$sync\.Summary\.LaunchTarget = \$terminalCmd/);
  assert.match(gui, /Start-Process -FilePath \$sync\.Summary\.LaunchTarget -WorkingDirectory \$sync\.Summary\.Workdir/);
  assert.doesNotMatch(gui, /Summary\.LaunchTarget = \$cfg\.SiteBaseUrl/);
  assert.match(cli, /CreateShortcut\(\(Join-Path \$desktopDir \(\$BrandName \+ ' Codex\.lnk'\)\)\)/);
  assert.match(cli, /Start-Process -FilePath \$launcherCmd -WorkingDirectory/);
});

test("Full Launcher keeps Store support and Portable Desktop is an explicit local build", async () => {
  const bootstrapper = await source("src/LauncherBootstrapper.cs");
  const build = await source("build/build-release.ps1");
  const gui = await source("installer/FluxGate-Codex-Setup-GUI.ps1");
  const workflow = await source(".github/workflows/release.yml");

  assert.match(bootstrapper, /FluxGate\.CodexLauncher\.OfficialCodexArchive/);
  assert.match(bootstrapper, /FluxGate\.CodexLauncher\.Notice/);
  assert.match(bootstrapper, /FluxGate\.CodexLauncher\.ThirdPartyLicenses/);
  assert.match(bootstrapper, /--self-test-full/);
  assert.match(bootstrapper, /FLUXGATE_CODEX_ARCHIVE/);
  assert.match(bootstrapper, /FLUXGATE_DESKTOP_ARCHIVE/);
  assert.match(bootstrapper, /FLUXGATE_PORTABLE_DESKTOP_V1/);
  assert.match(bootstrapper, /--self-test-portable/);
  assert.match(build, /codex-x86_64-pc-windows-msvc\.exe\.zip/);
  assert.match(build, /codex-command-runner\.exe/);
  assert.match(build, /codex-windows-sandbox-setup\.exe/);
  assert.match(build, /Official Codex CLI release does not provide a SHA-256 digest/);
  assert.match(build, /gh\.exe/);
  assert.match(build, /releaseHeaders\.Authorization = 'Bearer ' \+ \$env:GH_TOKEN/);
  assert.match(workflow, /GH_TOKEN: \$\{\{ github\.token \}\}/);
  assert.match(gui, /Get-AppxPackage -Name 'OpenAI\.Codex'/);
  assert.match(gui, /'9PLM9XGG6VKS'/);
  assert.match(gui, /DesktopPortableMode/);
  assert.match(gui, /DesktopOfficialMode/);
  assert.match(gui, /DesktopNoneMode/);
  assert.match(gui, /Join-Path \$root 'desktop-app'/);
  assert.match(gui, /Join-Path \$root 'portable-desktop\.json'/);
  assert.match(gui, /portableManifest\.user_data_included -ne \$false/);
  assert.match(gui, /便携版固定为打包时版本，不注册 Microsoft Store，也不自动更新/);
  assert.match(gui, /--user-data-dir=/);
  assert.match(gui, /EnvironmentVariables\['CODEX_HOME'\]/);
  assert.match(gui, /\$lines\[\$index\] = 'model = "'/);
  assert.match(gui, /NOTICE\.txt/);
  assert.match(gui, /THIRD-PARTY-LICENSES\.md/);
  assert.match(workflow, /GetManifestResourceStream/);
  assert.match(workflow, /FluxGate\.CodexLauncher\.OfficialCodexArchive/);
  assert.doesNotMatch(workflow, /& \$full\.FullName --self-test-full/);
  assert.match(build, /\[switch\]\$BuildPortableDesktop/);
  assert.match(build, /\[string\]\$PortableDesktopDir/);
  assert.match(build, /FluxGate-Codex-Desktop-Portable_\$Version\.exe/);
  assert.match(build, /portable-desktop-manifest\.json/);
  assert.match(build, /user_data_included = \$false/);
  assert.match(build, /auth\\\.json\|cookies\?/);
  assert.match(build, /Portable Desktop EXE exceeds the GitHub Releases 2 GB per-file limit/);
  assert.match(build, /Start-Process -FilePath \$exePath -ArgumentList '--self-test' -Wait -PassThru/);
  assert.match(build, /Start-Process -FilePath \$fullExePath -ArgumentList '--self-test-full' -Wait -PassThru/);
  assert.match(build, /Start-Process -FilePath \$portableExePath -ArgumentList '--self-test-portable' -Wait -PassThru/);
});

test("downloadable mobile page uses one-use Bridge tickets", async () => {
  const mobile = await source("mobile-web/index.html");
  const embedded = await source("server-integration/desktop_connect.html");
  assert.equal(mobile, embedded);
  assert.match(mobile, /API_TICKET\s*=\s*"\/api\/desktop\/bridge\/ticket"/);
  assert.match(mobile, /new WebSocket\(wsUrl\(\),\["fluxgate-bridge","ticket\."\+ticket\]\)/);
  assert.match(mobile, /window\.FluxNative\.requestBridgeTicket\(callbackId\)/);
  assert.doesNotMatch(mobile, /bridge\/phone\?token=|data\.access_token/);
});
