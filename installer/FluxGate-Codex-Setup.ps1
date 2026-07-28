# ============================================================================
#  FluxGateAI · Codex 一键安装器 (Windows / 命令行版)  v2.1.1
# ----------------------------------------------------------------------------
#  功能：
#    1. 在专属目录安装官方 OpenAI Codex CLI 独立二进制
#    2. 写入隔离 CODEX_HOME/config.toml，将上游指向 FluxGateAI 网关
#    3. 引导用户粘贴 FluxGate API Key（sk-...）并注入 Codex 登录态
#    4. 验证网关连通性与 Key 有效性，跑一次最小化冒烟测试
#
#  用法：
#    右键"使用 PowerShell 运行"，或在终端执行：
#      powershell -NoProfile -ExecutionPolicy Bypass -File .\FluxGate-Codex-Setup.ps1
#    可选参数：
#      -ApiKey sk-xxxx   非交互式传入 Key
#      -Reconfigure      跳过安装，只重写配置与登录
#      -SkipTest         跳过冒烟测试
# ============================================================================
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ApiKey = '',
    [switch]$Reconfigure,
    [switch]$SkipTest
)

# ========================= 品牌与网关配置（分发前只改这里） =========================
$BrandName      = 'FluxGateAI'
$ProviderId     = 'fluxgate'                          # config.toml 里的 provider 标识
$GatewayBaseUrl = 'https://api.fluxapi.cloud/v1'      # FluxGate 网关 OpenAI 兼容地址
$ConsoleUrl     = 'https://api.fluxapi.cloud'         # 控制台/注册地址（提示用户去建 Key）
$DefaultModel   = 'gpt-5.4-mini'                      # 默认模型（会对照 /v1/models 校验）
$GitHubProxy    = ''                                  # 大陆加速可填 'https://gh-proxy.com/'
$LauncherDirName = 'FluxGateAICodexLauncher'          # %APPDATA% 下的专属目录名
# ==============================================================================
# v2.0：隔离架构。全部文件只写 %APPDATA%\FluxGateAICodexLauncher，绝不修改 ~/.codex。
$LauncherRoot = Join-Path $env:APPDATA $LauncherDirName

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$script:StepIndex = 0
function Write-Step([string]$Text) {
    $script:StepIndex++
    Write-Host ''
    Write-Host ("[$script:StepIndex] $Text") -ForegroundColor Cyan
}
function Write-Ok([string]$Text)   { Write-Host ("  √ " + $Text) -ForegroundColor Green }
function Write-Warn2([string]$Text){ Write-Host ("  ! " + $Text) -ForegroundColor Yellow }
function Write-Fail([string]$Text) { Write-Host ("  × " + $Text) -ForegroundColor Red }

function Show-Banner {
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor Magenta
    Write-Host ('    ' + $BrandName.ToUpper() + '  x  CODEX') -ForegroundColor Magenta
    Write-Host '  ============================================================' -ForegroundColor Magenta
    Write-Host ("  $BrandName Codex 一键安装器 v2.1.1") -ForegroundColor White
    Write-Host ("  网关: $GatewayBaseUrl") -ForegroundColor DarkGray
    Write-Host '  ------------------------------------------------------------'
}

# ---------------------------------------------------------------------------
# Codex 定位与安装
# ---------------------------------------------------------------------------
$InstallDir = Join-Path $LauncherRoot 'codex-bin'

function Get-CodexCommand {
    $local = Join-Path $InstallDir 'codex.exe'
    if (Test-Path -LiteralPath $local) {
        try {
            $version = (& $local --version 2>&1 | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $version -match '^codex-cli\s') { return $local }
        } catch {}
        Write-Warn2 '现有独立 CLI 不完整，将自动修复'
    }
    return $null
}

function Install-CodexStandalone {
    Write-Host '  从 GitHub Releases 下载官方独立二进制...' -ForegroundColor DarkGray
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64-pc-windows' } else { 'x86_64-pc-windows' }
    $assetName = 'codex-' + $arch + '-msvc.exe.zip'
    $apiUrl = 'https://api.github.com/repos/openai/codex/releases/latest'
    if ($GitHubProxy) { $apiUrl = $GitHubProxy.TrimEnd('/') + '/' + $apiUrl }
    $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = "$BrandName-installer" } -TimeoutSec 60
    $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if (-not $asset) { throw "未在最新 Release 中找到官方 Codex CLI 主资产: $assetName" }
    $dlUrl = $asset.browser_download_url
    if ($GitHubProxy) { $dlUrl = $GitHubProxy.TrimEnd('/') + '/' + $dlUrl }

    $tmpZip = Join-Path $env:TEMP ("codex-" + [guid]::NewGuid().ToString('N') + '.zip')
    $tmpDir = Join-Path $env:TEMP ("codex-unzip-" + [guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri $dlUrl -OutFile $tmpZip -UseBasicParsing -TimeoutSec 600
        $expectedDigest = [string]$asset.digest
        if ($expectedDigest -match '^sha256:([0-9a-fA-F]{64})$') {
            $actualDigest = (Get-FileHash -Algorithm SHA256 -LiteralPath $tmpZip).Hash
            if ($actualDigest -ne $Matches[1]) { throw '官方 Codex CLI 下载文件校验失败' }
        }
        Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmpDir -Force
        $mainName = 'codex-' + $arch + '-msvc.exe'
        $mainExe = Get-ChildItem -LiteralPath $tmpDir -Recurse -File -Filter $mainName | Select-Object -First 1
        if (-not $mainExe) { throw "官方压缩包中未找到主程序: $mainName" }

        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Get-ChildItem -LiteralPath $InstallDir -Force | Remove-Item -Recurse -Force
        Get-ChildItem -LiteralPath $mainExe.Directory.FullName -Force | Copy-Item -Destination $InstallDir -Recurse -Force
        Move-Item -LiteralPath (Join-Path $InstallDir $mainName) -Destination (Join-Path $InstallDir 'codex.exe') -Force
        $installedVersion = (& (Join-Path $InstallDir 'codex.exe') --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $installedVersion -notmatch '^codex-cli\s') {
            throw '官方 Codex CLI 安装后启动验证失败'
        }
    } finally {
        Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 隔离设计：不修改全局 PATH，启动器 cmd 内部临时注入
    if ($env:Path -notlike "*$InstallDir*") { $env:Path = $InstallDir + ';' + $env:Path }
    return $true
}

# ---------------------------------------------------------------------------
# 配置写入
# ---------------------------------------------------------------------------
function Get-CodexHome {
    # 隔离 CODEX_HOME：只用专属目录，绝不返回 ~/.codex
    return (Join-Path $LauncherRoot 'codex-home')
}

function Write-CodexConfig {
    $codexHome = Get-CodexHome
    New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
    $configPath = Join-Path $codexHome 'config.toml'

    if (Test-Path -LiteralPath $configPath) {
        $backup = $configPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $configPath -Destination $backup -Force
        Write-Warn2 "检测到已有配置，已备份到: $backup"
    }

    $lines = @(
        "# 由 $BrandName 一键安装器生成 · $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "model = `"$DefaultModel`"",
        "model_provider = `"$ProviderId`"",
        "preferred_auth_method = `"apikey`"",
        "# 网关为无状态转发，关闭服务端响应存储依赖",
        "disable_response_storage = true",
        "",
        "[model_providers.$ProviderId]",
        "name = `"$BrandName`"",
        "base_url = `"$GatewayBaseUrl`"",
        "wire_api = `"responses`"",
        "requires_openai_auth = true",
        "",
        "[windows]",
        "sandbox = `"unelevated`""
    )
    Set-Content -LiteralPath $configPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
    Write-Ok "已写入配置: $configPath"
    return $configPath
}

# ---------------------------------------------------------------------------
# API Key 注入
# ---------------------------------------------------------------------------
function Read-ApiKeyInteractive {
    Write-Host ''
    Write-Host ("  请粘贴你的 $BrandName API Key（形如 sk-xxxx）") -ForegroundColor White
    Write-Host ("  没有 Key？请先到控制台创建令牌: $ConsoleUrl") -ForegroundColor DarkGray
    $secure = Read-Host '  API Key' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Set-CodexApiKey([string]$CodexExe, [string]$Key) {
    # 隔离设计：直接把凭证写入专属 codex-home 的 auth.json（与官方 CLI 格式一致），
    # 不调用 codex login，避免误写全局 ~/.codex。
    $codexHome = Get-CodexHome
    New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
    $authPath = Join-Path $codexHome 'auth.json'
    $json = '{"OPENAI_API_KEY":"' + $Key.Replace('\', '\\').Replace('"', '\"') + '"}'
    Set-Content -LiteralPath $authPath -Value $json -Encoding ASCII
    Write-Ok ('API Key 已写入隔离目录: ' + $authPath)
}

function Restore-V1GlobalConfig {
    # v1 版本曾写入 ~/.codex，v2 起自动还原
    $globalHome = Join-Path $env:USERPROFILE '.codex'
    $globalCfg = Join-Path $globalHome 'config.toml'
    if (-not (Test-Path -LiteralPath $globalCfg)) { return }
    $firstLine = Get-Content -LiteralPath $globalCfg -TotalCount 1 -ErrorAction SilentlyContinue
    if ($firstLine -notmatch '由 FluxGateAI 一键安装器生成') { return }
    $bak = Get-ChildItem -LiteralPath $globalHome -Filter 'config.toml.bak-*' -ErrorAction SilentlyContinue |
           Sort-Object Name -Descending | Select-Object -First 1
    if ($bak) {
        Copy-Item -LiteralPath $bak.FullName -Destination $globalCfg -Force
        Write-Warn2 ('检测到 v1 版曾修改 ~/.codex/config.toml，已还原备份: ' + $bak.Name)
        Write-Warn2 '如官方 Codex/Desktop 登录态丢失，请在官方应用中重新登录一次'
    }
}

function New-FluxLauncher([string]$CliPath) {
    # 生成终端启动器 + 桌面快捷方式（CODEX_HOME 只在启动器内注入）
    $codexHome = Get-CodexHome
    $cliDir = Split-Path $CliPath -Parent
    $terminalCmd = Join-Path $LauncherRoot ($BrandName + ' Codex 终端.cmd')
    $tLines = @(
        '@echo off',
        ('set "CODEX_HOME=' + $codexHome + '"'),
        ('set "CODEX_INSTALL_DIR=' + $InstallDir + '"'),
        ('set "PATH=' + $InstallDir + ';' + $cliDir + ';%PATH%"'),
        ('title ' + $BrandName + ' Codex'),
        ('echo [' + $BrandName + '] Codex 已连接 ' + $BrandName + ' 网关（独立 CODEX_HOME）'),
        'codex %*',
        'if errorlevel 1 pause'
    )
    # cmd 批处理按系统 ANSI 代码页解析，用 Default 编码写入以保住中文横幅与中文路径
    Set-Content -LiteralPath $terminalCmd -Value ($tLines -join "`r`n") -Encoding Default
    try {
        $desktopDir = [Environment]::GetFolderPath('Desktop')
        if ([string]::IsNullOrWhiteSpace($desktopDir) -or -not (Test-Path -LiteralPath $desktopDir)) {
            Write-Warn2 '未找到桌面目录，跳过快捷方式创建（可直接运行上面的启动器 cmd）'
        } else {
            $wsh = New-Object -ComObject WScript.Shell
            $lnk = $wsh.CreateShortcut((Join-Path $desktopDir ($BrandName + ' Codex.lnk')))
            $lnk.TargetPath = $terminalCmd
            $lnk.WorkingDirectory = [Environment]::GetFolderPath('UserProfile')
            $lnk.Description = ($BrandName + ' Codex 终端（独立配置）')
            $lnk.Save()
            $legacyShortcut = Join-Path $desktopDir ($BrandName + ' Codex 终端.lnk')
            if (Test-Path -LiteralPath $legacyShortcut) { Remove-Item -LiteralPath $legacyShortcut -Force }
            Write-Ok '桌面快捷方式已创建'
        }
    } catch { Write-Warn2 ('创建快捷方式失败: ' + $_.Exception.Message) }

    # 卸载脚本：README 与 GUI 版都承诺有它，CLI 版同样要给，否则用户无从删除写在
    # 隔离目录里的 API Key。用 cmd /s /c 让 cmd 只剥最外层引号，路径含空格才删得掉。
    $uninstallCmd = Join-Path $LauncherRoot '卸载.cmd'
    $uLines = @(
        '@echo off',
        ('echo Removing ' + $BrandName + ' Codex Launcher (your official Codex is untouched)...')
    )
    if ($desktopDir -and (Test-Path -LiteralPath $desktopDir)) {
        $uLines += ('del "' + (Join-Path $desktopDir ($BrandName + ' Codex.lnk')) + '" 2>nul')
        $uLines += ('del "' + (Join-Path $desktopDir ($BrandName + ' Codex 终端.lnk')) + '" 2>nul')
    }
    $uLines += ('start "" cmd /s /c "timeout /t 2 >nul & rd /s /q "' + $LauncherRoot + '""')
    Set-Content -LiteralPath $uninstallCmd -Value ($uLines -join "`r`n") -Encoding Default
    Write-Ok ('卸载脚本已生成: ' + $uninstallCmd)

    return $terminalCmd
}

# ---------------------------------------------------------------------------
# 网关验证
# ---------------------------------------------------------------------------
function Test-GatewayModels([string]$Key) {
    $headers = @{ Authorization = "Bearer $Key" }
    $resp = Invoke-RestMethod -Uri ($GatewayBaseUrl.TrimEnd('/') + '/models') -Headers $headers -TimeoutSec 30
    $ids = @()
    if ($resp -and $resp.data) { $ids = @($resp.data | ForEach-Object { $_.id }) }
    return $ids
}

function Test-GatewaySmoke([string]$Key, [string]$Model) {
    $headers = @{ Authorization = "Bearer $Key"; 'Content-Type' = 'application/json' }
    $body = '{"model":"' + $Model + '","input":"Reply only OK.","max_output_tokens":16}'
    return Invoke-RestMethod -Uri ($GatewayBaseUrl.TrimEnd('/') + '/responses') -Method Post -Headers $headers -Body $body -TimeoutSec 120
}

# ===========================================================================
#  主流程
# ===========================================================================
Show-Banner

# --- 0. 隔离目录 + 历史版本修复 ---
Write-Step "初始化专属目录（$LauncherRoot）"
New-Item -ItemType Directory -Path $LauncherRoot -Force | Out-Null
Restore-V1GlobalConfig
Write-Ok '隔离环境就绪，本安装器不会修改 ~/.codex'

# --- 1. Codex CLI ---
Write-Step '检测 / 安装官方 Codex CLI'
$codexExe = Get-CodexCommand
if ($codexExe -and -not $Reconfigure) {
    Write-Ok "已检测到 Codex: $codexExe"
} elseif (-not $codexExe) {
    if ($Reconfigure) { throw '未检测到 Codex，-Reconfigure 需要先完成安装。去掉该参数重新运行即可。' }
    $installed = Install-CodexStandalone
    $codexExe = Get-CodexCommand
    if (-not $installed -or -not $codexExe) { throw 'Codex 独立二进制安装失败，请检查网络后重试。' }
    Write-Ok "Codex 安装完成: $codexExe"
}
try {
    $ver = (& $codexExe --version 2>&1 | Out-String).Trim()
    if ($ver) { Write-Host ("  版本: " + $ver) -ForegroundColor DarkGray }
} catch {}

# --- 2. API Key ---
Write-Step "获取 $BrandName API Key"
if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = Read-ApiKeyInteractive }
$ApiKey = $ApiKey.Trim()
if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw '未输入 API Key。' }
if ($ApiKey -notlike 'sk-*') { Write-Warn2 'Key 不是 sk- 开头，仍尝试继续（如网关另有格式可忽略此提示）。' }
Write-Ok ('已读取 Key: ' + $ApiKey.Substring(0, [Math]::Min(8, $ApiKey.Length)) + '****')

# --- 3. 验证 Key + 模型可用性 ---
Write-Step '验证网关连通性与 Key 有效性'
$modelIds = @()
try {
    $modelIds = Test-GatewayModels -Key $ApiKey
    Write-Ok ("网关连通，Key 有效。可用模型 " + $modelIds.Count + " 个")
} catch {
    $msg = $_.Exception.Message
    if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
        throw "网关返回 401：API Key 无效或已禁用。请到 $ConsoleUrl 检查令牌。"
    }
    Write-Warn2 ("模型列表获取失败（$msg），继续安装，稍后请自行验证。")
}
if ($modelIds.Count -gt 0 -and ($modelIds -notcontains $DefaultModel)) {
    Write-Warn2 "默认模型 '$DefaultModel' 不在你的可用模型列表中。"
    $show = $modelIds | Select-Object -First 15
    Write-Host ('  可用模型: ' + ($show -join ', ')) -ForegroundColor DarkGray
    $picked = Read-Host "  输入要使用的模型名（直接回车 = 仍用 $DefaultModel）"
    if (-not [string]::IsNullOrWhiteSpace($picked)) { $DefaultModel = $picked.Trim() }
}

# --- 4. 写配置 ---
Write-Step '写入 Codex 配置（config.toml）'
$configPath = Write-CodexConfig

# --- 5. 注入登录态（隔离目录） ---
Write-Step '写入 API Key（隔离 codex-home）'
Set-CodexApiKey -CodexExe $codexExe -Key $ApiKey

# --- 5.5 生成启动器与快捷方式 ---
Write-Step '生成启动器与桌面快捷方式'
$launcherCmd = New-FluxLauncher -CliPath $codexExe

# --- 6. 冒烟测试 ---
if (-not $SkipTest) {
    Write-Step "冒烟测试（模型: $DefaultModel，约消耗几十 token）"
    try {
        $null = Test-GatewaySmoke -Key $ApiKey -Model $DefaultModel
        Write-Ok '网关 /responses 转发正常，安装收尾。'
    } catch {
        Write-Warn2 ('冒烟测试未通过: ' + $_.Exception.Message)
        Write-Warn2 '常见原因：模型名与网关侧不一致 / 渠道未开通该模型。可在控制台调整后直接使用，无需重装。'
    }
}

# --- 完成 ---
Write-Host ''
Write-Host '  ------------------------------------------------------------'
Write-Host ("  √ $BrandName Codex 安装完成！") -ForegroundColor Green
Write-Host ''
Write-Host '  使用方法：' -ForegroundColor White
Write-Host ("    双击桌面的「$BrandName Codex」快捷方式即可使用")
Write-Host '    （独立配置，不影响你原有的 Codex / Codex Desktop）'
Write-Host ''
Write-Host ("  安装目录: " + $LauncherRoot) -ForegroundColor DarkGray
Write-Host ("  启动器:   " + $launcherCmd) -ForegroundColor DarkGray
Write-Host ("  配置文件: " + $configPath) -ForegroundColor DarkGray
Write-Host ("  控制台:   " + $ConsoleUrl) -ForegroundColor DarkGray
Write-Host '  ------------------------------------------------------------'
try {
    Start-Process -FilePath $launcherCmd -WorkingDirectory ([Environment]::GetFolderPath('UserProfile'))
} catch {
    Write-Warn2 '终端未能自动打开，请双击桌面的 Codex 快捷方式'
}
