param(
    [string]$Version = '2.2.0',
    [string]$OutputDir = '',
    [switch]$BuildFull,
    [string]$CodexArchive = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) {
    $OutputDir = Join-Path $root 'release-assets'
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$scripts = @(
    (Join-Path $root 'installer\FluxGate-Codex-Setup.ps1'),
    (Join-Path $root 'installer\FluxGate-Codex-Setup-GUI.ps1'),
    (Join-Path $root 'build\build-release.ps1')
)
foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw "PowerShell syntax validation failed for $script`: $($errors[0].Message)"
    }
}

& node --check (Join-Path $root 'bridge\fluxgate-bridge.mjs')
if ($LASTEXITCODE -ne 0) {
    throw 'Bridge JavaScript syntax validation failed'
}
& node --check (Join-Path $root 'bridge\mobile-mock-server.mjs')
if ($LASTEXITCODE -ne 0) {
    throw 'Mobile preview server syntax validation failed'
}
& node --test (Join-Path $root 'tests\production-contract.test.mjs')
if ($LASTEXITCODE -ne 0) {
    throw 'Production contract validation failed'
}

$mobilePage = Join-Path $root 'mobile-web\index.html'
$embeddedPage = Join-Path $root 'server-integration\desktop_connect.html'
if ((Get-FileHash $mobilePage).Hash -ne (Get-FileHash $embeddedPage).Hash) {
    throw 'The mobile page and server embedded page are out of sync'
}
$html = Get-Content -LiteralPath $mobilePage -Raw -Encoding UTF8
$scriptMatch = [regex]::Match($html, '(?s)<script>(.*?)</script>')
if (-not $scriptMatch.Success) {
    throw 'The mobile page script could not be extracted'
}
$tempJavaScript = Join-Path ([IO.Path]::GetTempPath()) ('fluxgate-mobile-' + [guid]::NewGuid().ToString('N') + '.js')
try {
    Set-Content -LiteralPath $tempJavaScript -Value $scriptMatch.Groups[1].Value -Encoding UTF8
    & node --check $tempJavaScript
    if ($LASTEXITCODE -ne 0) {
        throw 'Mobile web JavaScript syntax validation failed'
    }
} finally {
    Remove-Item -LiteralPath $tempJavaScript -Force -ErrorAction SilentlyContinue
}

$cscCandidates = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) {
    throw 'The .NET Framework C# compiler was not found'
}

$exeName = "FluxGate-Codex-Launcher_$Version.exe"
$exePath = Join-Path $OutputDir $exeName
$fullExePath = Join-Path $OutputDir "FluxGate-Codex-Full_$Version.exe"
$source = Join-Path $root 'src\LauncherBootstrapper.cs'
$companionSource = Join-Path $root 'src\Companion.cs'
$guiScript = Join-Path $root 'installer\FluxGate-Codex-Setup-GUI.ps1'
$icon = Join-Path $root 'assets\fluxgate-launcher.ico'
$notice = Join-Path $root 'NOTICE'
$thirdPartyLicenses = Join-Path $root 'THIRD-PARTY-LICENSES.md'
$companionExe = Join-Path ([IO.Path]::GetTempPath()) ('FluxGate-Codex-Companion-' + [guid]::NewGuid().ToString('N') + '.exe')
$temporaryCodexArchive = $null

try {
    & $csc /nologo /target:winexe /platform:anycpu /optimize+ "/win32icon:$icon" `
        /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:Microsoft.CSharp.dll `
        "/out:$companionExe" $companionSource
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $companionExe)) {
        throw 'Companion EXE build failed'
    }
    & $companionExe --self-test
    if ($LASTEXITCODE -ne 0) {
        throw 'Companion EXE self-test failed'
    }
    $oldCompanionExe = $env:FLUXGATE_COMPANION_EXE
    try {
        $env:FLUXGATE_COMPANION_EXE = $companionExe
        & node --test (Join-Path $root 'tests\companion.integration.test.mjs')
        if ($LASTEXITCODE -ne 0) {
            throw 'Companion integration test failed'
        }
    } finally {
        $env:FLUXGATE_COMPANION_EXE = $oldCompanionExe
    }

    & $csc /nologo /target:winexe /platform:anycpu /optimize+ "/win32icon:$icon" `
        "/resource:$guiScript,FluxGate.CodexLauncher.SetupScript" `
        "/resource:$companionExe,FluxGate.CodexLauncher.Companion" `
        "/resource:$notice,FluxGate.CodexLauncher.Notice" `
        "/resource:$thirdPartyLicenses,FluxGate.CodexLauncher.ThirdPartyLicenses" `
        "/out:$exePath" $source
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
        throw 'Launcher EXE build failed'
    }

    & $exePath --self-test
    if ($LASTEXITCODE -ne 0) {
        throw 'Launcher EXE embedded-resource self-test failed'
    }

    if ($BuildFull) {
        $archivePath = $CodexArchive
        if ([string]::IsNullOrWhiteSpace($archivePath)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/openai/codex/releases/latest' `
                -Headers @{ 'User-Agent' = 'fluxgate-release-builder' } -TimeoutSec 60
            $assetName = 'codex-x86_64-pc-windows-msvc.exe.zip'
            $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
            if (-not $asset) { throw "Official Codex CLI asset not found: $assetName" }
            $temporaryCodexArchive = Join-Path ([IO.Path]::GetTempPath()) ('official-codex-' + [guid]::NewGuid().ToString('N') + '.zip')
            Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $temporaryCodexArchive -TimeoutSec 600
            $expectedDigest = [string]$asset.digest
            if ($expectedDigest -notmatch '^sha256:([0-9a-fA-F]{64})$') {
                throw 'Official Codex CLI release does not provide a SHA-256 digest'
            }
            $actualDigest = (Get-FileHash -Algorithm SHA256 -LiteralPath $temporaryCodexArchive).Hash
            if ($actualDigest -ne $Matches[1]) { throw 'Official Codex CLI archive checksum mismatch' }
            $archivePath = $temporaryCodexArchive
        }
        $archivePath = [IO.Path]::GetFullPath($archivePath)
        if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
            throw "Official Codex CLI archive not found: $archivePath"
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
        try {
            $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
            foreach ($requiredEntry in @(
                'codex-x86_64-pc-windows-msvc.exe',
                'codex-command-runner.exe',
                'codex-windows-sandbox-setup.exe'
            )) {
                if ($entryNames -notcontains $requiredEntry) {
                    throw "Official Codex CLI archive is missing $requiredEntry"
                }
            }
        } finally {
            $archive.Dispose()
        }

        & $csc /nologo /target:winexe /platform:x64 /optimize+ "/win32icon:$icon" `
            "/resource:$guiScript,FluxGate.CodexLauncher.SetupScript" `
            "/resource:$companionExe,FluxGate.CodexLauncher.Companion" `
            "/resource:$archivePath,FluxGate.CodexLauncher.OfficialCodexArchive" `
            "/resource:$notice,FluxGate.CodexLauncher.Notice" `
            "/resource:$thirdPartyLicenses,FluxGate.CodexLauncher.ThirdPartyLicenses" `
            "/out:$fullExePath" $source
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $fullExePath)) {
            throw 'Full Launcher EXE build failed'
        }
        & $fullExePath --self-test-full
        if ($LASTEXITCODE -ne 0) {
            throw 'Full Launcher EXE embedded-resource self-test failed'
        }
    }
} finally {
    Remove-Item -LiteralPath $companionExe -Force -ErrorAction SilentlyContinue
    if ($temporaryCodexArchive) {
        Remove-Item -LiteralPath $temporaryCodexArchive -Force -ErrorAction SilentlyContinue
    }
}

$deliverables = @{
    'FluxGate-Codex-Setup.ps1' = 'installer\FluxGate-Codex-Setup.ps1'
    'FluxGate-Codex-Setup-GUI.ps1' = 'installer\FluxGate-Codex-Setup-GUI.ps1'
    'Install-FluxGate-Codex.bat' = 'installer\Install-FluxGate-Codex.bat'
    'Install-FluxGate-Codex-GUI.bat' = 'installer\Install-FluxGate-Codex-GUI.bat'
}
foreach ($entry in $deliverables.GetEnumerator()) {
    Copy-Item -Force (Join-Path $root $entry.Value) (Join-Path $OutputDir $entry.Key)
}

$bridgeZip = Join-Path $OutputDir "FluxGate-Codex-Bridge_$Version.zip"
$bridgeFiles = Get-ChildItem -LiteralPath (Join-Path $root 'bridge') -File | Where-Object {
    @('.mjs', '.json', '.md', '.bat') -contains $_.Extension.ToLowerInvariant()
} | Select-Object -ExpandProperty FullName
Compress-Archive -LiteralPath $bridgeFiles -DestinationPath $bridgeZip -Force

$mobileZip = Join-Path $OutputDir "FluxGate-Codex-Mobile-Web_$Version.zip"
Compress-Archive -Path (Join-Path $root 'mobile-web\*') -DestinationPath $mobileZip -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($advancedZip in @($bridgeZip, $mobileZip)) {
    $zip = [IO.Compression.ZipFile]::OpenRead($advancedZip)
    try {
        $forbidden = @($zip.Entries | Where-Object {
            $_.FullName.Replace('\', '/') -match '(?i)(^|/)(codex(?:-[^/]+)?\.exe|app\.asar)$'
        })
        if ($forbidden.Count -gt 0) {
            throw "Advanced asset contains an official Codex payload: $($forbidden[0].FullName)"
        }
    } finally {
        $zip.Dispose()
    }
}

Get-ChildItem -LiteralPath $OutputDir -File | Select-Object Name, Length
