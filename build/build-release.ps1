param(
    [string]$Version = '2.0.0',
    [string]$OutputDir = ''
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
$source = Join-Path $root 'src\LauncherBootstrapper.cs'
$guiScript = Join-Path $root 'installer\FluxGate-Codex-Setup-GUI.ps1'
$icon = Join-Path $root 'assets\fluxgate-launcher.ico'

& $csc /nologo /target:winexe /platform:anycpu /optimize+ "/win32icon:$icon" "/resource:$guiScript,FluxGate.CodexLauncher.SetupScript" "/out:$exePath" $source
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
    throw 'Launcher EXE build failed'
}

& $exePath --self-test
if ($LASTEXITCODE -ne 0) {
    throw 'Launcher EXE embedded-resource self-test failed'
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

Get-ChildItem -LiteralPath $OutputDir -File | Select-Object Name, Length
