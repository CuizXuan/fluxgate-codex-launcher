# ============================================================================
#  FluxGateAI · Codex 一键安装器 (Windows / 图形界面版)  v2.0.1
# ----------------------------------------------------------------------------
#  隔离 Launcher 架构：
#    %APPDATA%\FluxGateAICodexLauncher\
#      codex-home\   独立 CODEX_HOME（config.toml / auth.json，只写这里）
#      codex-bin\    独立 CLI 二进制（不改全局 PATH）
#      app\          可选的 Codex Desktop 本地副本（发布物不包含官方二进制）
#      logs\         安装日志
#    ！！本安装器绝不写入 ~/.codex，不影响你现有的 Codex / Codex Desktop。
#    首次运行会检测 v1 版对 ~/.codex 的修改并自动还原备份。
#
#  登录方式：FluxGate 账号密码（需后端 /api/desktop/codex 端点）或粘贴 API Key
#  打包：从仓库根目录运行 build\build-release.ps1
# ============================================================================
#requires -Version 5.1

# ===================== 品牌与网关配置（分发前只改这里） =====================
$BrandName      = 'FluxGateAI'
$ProviderId     = 'fluxgate'
$GatewayBaseUrl = 'https://api.fluxapi.cloud/v1'
$SiteBaseUrl    = 'https://api.fluxapi.cloud'         # 控制台 / desktop API 根地址
$DefaultModel   = 'gpt-5.4-mini'
$GitHubProxy    = ''                                  # 大陆加速可填 'https://gh-proxy.com/'
$NpmMirror      = 'https://registry.npmmirror.com'
$AppVersion     = 'v2.0.1'
$LauncherDirName = 'FluxGateAICodexLauncher'          # %APPDATA% 下的专属目录名
# ==========================================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

# ---------------------------------------------------------------------------
# XAML 界面
# ---------------------------------------------------------------------------
$xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="__BRAND__ Codex 安装器" Width="640" Height="720"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        FontFamily="Segoe UI" TextOptions.TextRenderingMode="ClearType">
  <Window.Resources>
    <SolidColorBrush x:Key="BgBrush"      Color="#0E1116"/>
    <SolidColorBrush x:Key="CardBrush"    Color="#161B22"/>
    <SolidColorBrush x:Key="BorderBrush2" Color="#2A313C"/>
    <SolidColorBrush x:Key="TextBrush"    Color="#E6EDF3"/>
    <SolidColorBrush x:Key="MutedBrush"   Color="#8B949E"/>
    <LinearGradientBrush x:Key="AccentGrad" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#4F8CFF" Offset="0"/>
      <GradientStop Color="#9B5CFF" Offset="1"/>
    </LinearGradientBrush>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource TextBrush}"/>
    </Style>

    <Style x:Key="InputStyle" TargetType="Control">
      <Setter Property="Background" Value="#0D1117"/>
      <Setter Property="Foreground" Value="#E6EDF3"/>
      <Setter Property="BorderBrush" Value="#2A313C"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>

    <Style x:Key="ModeRadio" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#E6EDF3"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="0,0,18,0"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>

    <Style x:Key="PrimaryBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" CornerRadius="8" Background="{StaticResource AccentGrad}" Padding="18,10">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Opacity" Value="0.88"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Background" Value="#3A4150"/>
                <Setter Property="Foreground" Value="#8B949E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="GhostBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#8B949E"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" CornerRadius="6" Background="Transparent" BorderBrush="#2A313C" BorderThickness="1" Padding="12,7">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1F2630"/>
                <Setter Property="Foreground" Value="#E6EDF3"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="LinkBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#4F8CFF"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <TextBlock Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" TextDecorations="Underline"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#8B949E"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Width" Value="34"/>
      <Setter Property="Height" Value="28"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="Transparent" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#232A35"/>
                <Setter Property="Foreground" Value="#E6EDF3"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border CornerRadius="14" Background="{StaticResource BgBrush}" BorderBrush="#232A35" BorderThickness="1">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- 标题栏 -->
      <Grid Grid.Row="0" x:Name="TitleBar" Background="Transparent" Height="64">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="22,0,0,0">
          <TextBlock Text="⚡" FontSize="22" VerticalAlignment="Center"/>
          <StackPanel Margin="10,0,0,0">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="__BRAND__" FontSize="19" FontWeight="Bold"/>
              <TextBlock Text="  Codex 安装器" FontSize="15" Foreground="{StaticResource MutedBrush}" VerticalAlignment="Bottom" Margin="2,0,0,1"/>
            </StackPanel>
            <TextBlock Text="独立目录安装 · 不影响你现有的 Codex" FontSize="11" Foreground="{StaticResource MutedBrush}"/>
          </StackPanel>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,10,12,0">
          <Button x:Name="BtnMin" Style="{StaticResource WinBtn}" Content="─"/>
          <Button x:Name="BtnClose" Style="{StaticResource WinBtn}" Content="✕"/>
        </StackPanel>
      </Grid>

      <!-- 内容区 -->
      <Grid Grid.Row="1" Margin="22,4,22,0">

        <!-- 表单页 -->
        <StackPanel x:Name="PanelForm">
          <Border Background="{StaticResource CardBrush}" BorderBrush="{StaticResource BorderBrush2}" BorderThickness="1" CornerRadius="10" Padding="18">
            <StackPanel>
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <RadioButton x:Name="ModeAccount" Style="{StaticResource ModeRadio}" Content="账号密码登录" IsChecked="True" GroupName="authmode"/>
                  <RadioButton x:Name="ModeApiKey" Style="{StaticResource ModeRadio}" Content="API Key" GroupName="authmode"/>
                </StackPanel>
                <Button x:Name="BtnGetKey" Style="{StaticResource LinkBtn}" Content="注册 / 控制台 →" HorizontalAlignment="Right"/>
              </Grid>

              <!-- 账号模式 -->
              <StackPanel x:Name="AccountFields" Margin="0,12,0,0">
                <TextBlock Text="__BRAND__ 账号" FontSize="12" Foreground="{StaticResource MutedBrush}"/>
                <TextBox x:Name="UserBox" Style="{StaticResource InputStyle}" Margin="0,6,0,0"/>
                <TextBlock Text="密码" FontSize="12" Foreground="{StaticResource MutedBrush}" Margin="0,10,0,0"/>
                <PasswordBox x:Name="PassBox" Style="{StaticResource InputStyle}" Margin="0,6,0,0"/>
                <TextBlock Text="登录后自动为你创建专用 API Key（名为 desktop-codex）" FontSize="11" Foreground="{StaticResource MutedBrush}" Margin="0,8,0,0"/>
              </StackPanel>

              <!-- Key 模式 -->
              <StackPanel x:Name="KeyFields" Margin="0,12,0,0" Visibility="Collapsed">
                <TextBlock Text="API Key" FontSize="12" Foreground="{StaticResource MutedBrush}"/>
                <Grid Margin="0,6,0,0">
                  <PasswordBox x:Name="KeyBox" Style="{StaticResource InputStyle}" FontFamily="Consolas"/>
                  <TextBox x:Name="KeyBoxPlain" Style="{StaticResource InputStyle}" FontFamily="Consolas" Visibility="Collapsed"/>
                  <Button x:Name="BtnEye" Style="{StaticResource WinBtn}" Content="👁" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,4,0"/>
                </Grid>
                <TextBlock Text="粘贴形如 sk-xxxx 的令牌，仅保存在本机独立目录" FontSize="11" Foreground="{StaticResource MutedBrush}" Margin="0,6,0,0"/>
              </StackPanel>
            </StackPanel>
          </Border>

          <Border Background="{StaticResource CardBrush}" BorderBrush="{StaticResource BorderBrush2}" BorderThickness="1" CornerRadius="10" Padding="18" Margin="0,12,0,0">
            <StackPanel>
              <Grid>
                <TextBlock Text="模型" FontSize="13" FontWeight="SemiBold"/>
                <Button x:Name="BtnValidate" Style="{StaticResource LinkBtn}" Content="验证并拉取模型列表" HorizontalAlignment="Right"/>
              </Grid>
              <ComboBox x:Name="ModelBox" IsEditable="True" Margin="0,8,0,0" FontSize="13" Padding="8,6" FontFamily="Consolas"/>
              <TextBlock x:Name="ModelHint" Text="可直接安装：会自动校验并匹配你账号下可用的模型" FontSize="11" Foreground="{StaticResource MutedBrush}" Margin="0,6,0,0"/>
            </StackPanel>
          </Border>

          <Border Background="{StaticResource CardBrush}" BorderBrush="{StaticResource BorderBrush2}" BorderThickness="1" CornerRadius="10" Padding="18,12" Margin="0,12,0,0">
            <StackPanel>
              <CheckBox x:Name="ChkDesktop" IsChecked="False" FontSize="12">
                <TextBlock Text="复用本机已安装的 Codex Desktop（仅本地复制；发布包不含官方程序）" Foreground="{StaticResource MutedBrush}" FontSize="12" TextWrapping="Wrap"/>
              </CheckBox>
              <CheckBox x:Name="ChkSmoke" IsChecked="True" Margin="0,8,0,0" FontSize="12">
                <TextBlock Text="安装完成后运行连通性测试（消耗少量 token）" Foreground="{StaticResource MutedBrush}" FontSize="12"/>
              </CheckBox>
              <TextBlock FontSize="11" Foreground="{StaticResource MutedBrush}" Margin="22,8,0,0" Text="__INSTALLDIR__"/>
              <TextBlock FontSize="11" Foreground="{StaticResource MutedBrush}" Margin="22,2,0,0" Text="__GATEWAY__"/>
            </StackPanel>
          </Border>

          <Button x:Name="BtnInstall" Style="{StaticResource PrimaryBtn}" Content="开 始 安 装" Margin="0,16,0,0" Height="44"/>
          <TextBlock x:Name="FormStatus" Text="" FontSize="12" Foreground="#F85149" Margin="0,8,0,0" TextWrapping="Wrap"/>
        </StackPanel>

        <!-- 进度页 -->
        <StackPanel x:Name="PanelProgress" Visibility="Collapsed">
          <Border Background="{StaticResource CardBrush}" BorderBrush="{StaticResource BorderBrush2}" BorderThickness="1" CornerRadius="10" Padding="20">
            <StackPanel>
              <TextBlock x:Name="StageText" Text="准备中..." FontSize="15" FontWeight="SemiBold"/>
              <Grid Margin="0,14,0,0">
                <Border Background="#0D1117" CornerRadius="4" Height="8"/>
                <Border x:Name="ProgFill" Background="{StaticResource AccentGrad}" CornerRadius="4" Height="8" HorizontalAlignment="Left" Width="0"/>
              </Grid>
              <TextBlock x:Name="PctText" Text="0%" FontSize="11" Foreground="{StaticResource MutedBrush}" Margin="0,6,0,0"/>
            </StackPanel>
          </Border>
          <Border Background="#0D1117" BorderBrush="{StaticResource BorderBrush2}" BorderThickness="1" CornerRadius="10" Margin="0,12,0,0">
            <ScrollViewer x:Name="LogScroll" Height="330" VerticalScrollBarVisibility="Auto" Padding="6">
              <TextBox x:Name="LogBox" Background="Transparent" Foreground="#9DA7B3" BorderThickness="0"
                       FontFamily="Consolas" FontSize="11.5" IsReadOnly="True" TextWrapping="Wrap"/>
            </ScrollViewer>
          </Border>
        </StackPanel>

        <!-- 完成页 -->
        <StackPanel x:Name="PanelDone" Visibility="Collapsed" Margin="0,10,0,0">
          <TextBlock Text="✓" FontSize="52" FontWeight="Bold" Foreground="#3FB950" HorizontalAlignment="Center"/>
          <TextBlock Text="安装完成" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,6,0,0"/>
          <TextBlock x:Name="DoneSub" Text="" FontSize="12" Foreground="{StaticResource MutedBrush}" HorizontalAlignment="Center" Margin="0,4,0,0" TextAlignment="Center" TextWrapping="Wrap"/>
          <Border Background="{StaticResource CardBrush}" BorderBrush="{StaticResource BorderBrush2}" BorderThickness="1" CornerRadius="10" Padding="18" Margin="0,16,0,0">
            <StackPanel>
              <TextBlock Text="已在桌面创建快捷方式" FontSize="13" FontWeight="SemiBold"/>
              <TextBlock x:Name="DoneShortcuts" FontSize="12.5" Foreground="{StaticResource MutedBrush}" Margin="0,8,0,0" TextWrapping="Wrap"
                         Text=""/>
            </StackPanel>
          </Border>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,18,0,0">
            <Button x:Name="BtnLaunch" Style="{StaticResource PrimaryBtn}" Content="启动 __BRAND__ Codex" Margin="0,0,10,0"/>
            <Button x:Name="BtnOpenDir" Style="{StaticResource GhostBtn}" Content="打开安装目录" Margin="0,0,10,0"/>
            <Button x:Name="BtnFinish" Style="{StaticResource GhostBtn}" Content="完 成"/>
          </StackPanel>
        </StackPanel>
      </Grid>

      <!-- 页脚 -->
      <TextBlock Grid.Row="2" Text="__FOOTER__" FontSize="10.5"
                 Foreground="#4B5563" HorizontalAlignment="Center" Margin="0,10,0,14"/>
    </Grid>
  </Border>
</Window>
'@

$LauncherRoot = Join-Path $env:APPDATA $LauncherDirName
$xamlText = $xamlText.Replace('__BRAND__', $BrandName)
$xamlText = $xamlText.Replace('__INSTALLDIR__', "安装位置：$LauncherRoot")
$xamlText = $xamlText.Replace('__GATEWAY__', "网关：$GatewayBaseUrl")
$xamlText = $xamlText.Replace('__FOOTER__', "$BrandName Codex Launcher $AppVersion  ·  $SiteBaseUrl")

$window = [Windows.Markup.XamlReader]::Parse($xamlText)
foreach ($name in @('TitleBar','BtnMin','BtnClose','PanelForm','PanelProgress','PanelDone',
        'ModeAccount','ModeApiKey','AccountFields','KeyFields','UserBox','PassBox',
        'KeyBox','KeyBoxPlain','BtnEye','BtnGetKey','ModelBox','ModelHint','BtnValidate',
        'ChkDesktop','ChkSmoke','BtnInstall','FormStatus','StageText','ProgFill','PctText',
        'LogBox','LogScroll','DoneSub','DoneShortcuts','BtnLaunch','BtnOpenDir','BtnFinish')) {
    Set-Variable -Name $name -Value $window.FindName($name)
}
$ModelBox.Items.Add($DefaultModel) | Out-Null
$ModelBox.SelectedIndex = 0

# ---------------------------------------------------------------------------
# 共享状态 + 后台工作线程
# ---------------------------------------------------------------------------
$sync = [hashtable]::Synchronized(@{
    Log      = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    Progress = 0; Stage = ''; Running = $false; Done = $false; Success = $false
    ModelIds = $null; ModelsFetched = $false; Summary = @{}
})

$workerScript = {
    param($sync, $cfg)
    $ErrorActionPreference = 'Continue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    function Log([string]$t)  { $sync.Log.Enqueue(('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $t)) }
    function Stage([string]$s, [int]$p) { $sync.Stage = $s; $sync.Progress = $p; Log ('== ' + $s) }

    # ---- 通用：账号登录直接获取专用 Key ----
    function Resolve-ApiKey {
        if ($cfg.AuthMode -eq 'key') {
            if ([string]::IsNullOrWhiteSpace($cfg.ApiKey)) { throw '未提供 API Key' }
            return @{ ApiKey = $cfg.ApiKey.Trim(); BaseUrl = $cfg.GatewayBaseUrl }
        }
        $api = $cfg.SiteBaseUrl.TrimEnd('/')
        $loginBody = ('{"username":' + (ConvertTo-Json $cfg.Username) + ',"password":' + (ConvertTo-Json $cfg.Password) + '}')
        try {
            $loginResp = Invoke-RestMethod -Uri ($api + '/api/desktop/codex/login') -Method Post -Body $loginBody -ContentType 'application/json' -TimeoutSec 30
        } catch {
            $status = 0
            if ($_.Exception.Response) { try { $status = [int]$_.Exception.Response.StatusCode } catch {} }
            if ($status -eq 404) { throw '网关尚未部署账号登录端点（/api/desktop/codex/login 返回 404），请切换到 API Key 模式' }
            throw ('登录请求失败: ' + $_.Exception.Message)
        }
        if (-not $loginResp.success) { throw ('登录失败: ' + $loginResp.message) }
        $key = [string]$loginResp.data.api_key
        if ([string]::IsNullOrWhiteSpace($key)) { throw '登录响应缺少专用 API Key' }
        $u = $loginResp.data.user
        if ($u) { Log ('登录成功: ' + $u.username + '（额度 ' + $u.quota + '）') }
        # 生产登录接口已经返回专用 Key。网关地址仍以安装器的 API 子域为准，
        # 避免站点 ServerAddress 把 Codex 配置指向控制台根域。
        $base = $cfg.GatewayBaseUrl
        Log ('已获取专用 API Key（desktop-codex）')
        return @{ ApiKey = $key; BaseUrl = $base }
    }

    function Get-Models([string]$Key, [string]$Base) {
        $resp = Invoke-RestMethod -Uri ($Base.TrimEnd('/') + '/models') -Headers @{ Authorization = "Bearer $Key" } -TimeoutSec 30
        if ($resp -and $resp.data) { return @($resp.data | ForEach-Object { $_.id }) }
        return @()
    }

    # ---- 模式一：仅验证 ----
    if ($cfg.Mode -eq 'validate') {
        try {
            Stage '正在验证...' 30
            $cred = Resolve-ApiKey
            $ids = Get-Models -Key $cred.ApiKey -Base $cred.BaseUrl
            $sync.ModelIds = $ids; $sync.ModelsFetched = $true
            Log ('验证通过，可用模型 ' + $ids.Count + ' 个')
            $sync.Success = $true
        } catch {
            $msg = $_.Exception.Message
            if ($_.Exception.Response) {
                try { if ([int]$_.Exception.Response.StatusCode -eq 401) { $msg = 'API Key 无效或已禁用（网关返回 401）' } } catch {}
            }
            Log ('验证失败: ' + $msg); $sync.Summary.Error = $msg
            $sync.ModelsFetched = $true; $sync.ModelIds = @(); $sync.Success = $false
        }
        $sync.Done = $true; return
    }

    # ---- 模式二：完整安装 ----
    try {
        $root      = $cfg.LauncherRoot
        $codexHome = Join-Path $root 'codex-home'
        $binDir    = Join-Path $root 'codex-bin'
        $appDir    = Join-Path $root 'app'
        $logsDir   = Join-Path $root 'logs'

        # 0. 修复 v1 版本对 ~/.codex 的影响（如有）
        Stage '检查历史版本影响（~/.codex 保护）' 4
        $globalHome = Join-Path $env:USERPROFILE '.codex'
        $globalCfg = Join-Path $globalHome 'config.toml'
        if (Test-Path -LiteralPath $globalCfg) {
            $firstLine = (Get-Content -LiteralPath $globalCfg -TotalCount 1 -ErrorAction SilentlyContinue)
            if ($firstLine -match '由 FluxGateAI 一键安装器生成') {
                $bak = Get-ChildItem -LiteralPath $globalHome -Filter 'config.toml.bak-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
                if ($bak) {
                    Copy-Item -LiteralPath $bak.FullName -Destination $globalCfg -Force
                    Log ('检测到 v1 版曾修改 ~/.codex/config.toml，已还原备份: ' + $bak.Name)
                    Log '提示：如官方 Codex/Desktop 登录态丢失，请在官方应用中重新登录一次'
                } else {
                    Log '检测到 v1 生成的 ~/.codex/config.toml 但未找到备份，保持不动'
                }
            } else {
                Log '~/.codex 为你自己的配置，本安装器不会触碰'
            }
        }

        # 1. 创建专属目录
        Stage ('创建专属目录 ' + $root) 8
        foreach ($d in @($root, $codexHome, $binDir, $logsDir)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
        Log ('目录就绪: ' + $root)

        # 2. Codex CLI（优先复用系统已有；否则下载独立版到专属目录，不改全局 PATH）
        Stage '定位 / 安装 Codex CLI' 14
        $cliPath = $null
        $localCli = Join-Path $binDir 'codex.exe'
        if (Test-Path -LiteralPath $localCli) { $cliPath = $localCli }
        if (-not $cliPath) {
            $cmd = Get-Command codex -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) { $cliPath = $cmd.Source; Log ('复用系统已有 Codex CLI: ' + $cliPath) }
        }
        if (-not $cliPath) {
            $npm = Get-Command npm -ErrorAction SilentlyContinue
            $installed = $false
            if ($npm) {
                Log '通过 npm 安装 @openai/codex ...'
                $null = (& npm install -g '@openai/codex' 2>&1 | Out-String)
                if ($LASTEXITCODE -ne 0 -and $cfg.NpmMirror) {
                    Log ('npm 直连失败，改用镜像重试: ' + $cfg.NpmMirror)
                    $null = (& npm install -g '@openai/codex' ('--registry=' + $cfg.NpmMirror) 2>&1 | Out-String)
                }
                if ($LASTEXITCODE -eq 0) {
                    $cmd = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($cmd) { $cliPath = $cmd.Source; $installed = $true }
                }
            }
            if (-not $installed) {
                Log '从 GitHub Releases 下载官方独立二进制...'
                $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64-pc-windows' } else { 'x86_64-pc-windows' }
                $apiUrl = 'https://api.github.com/repos/openai/codex/releases/latest'
                if ($cfg.GitHubProxy) { $apiUrl = $cfg.GitHubProxy.TrimEnd('/') + '/' + $apiUrl }
                $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'fluxgate-installer' } -TimeoutSec 60
                $asset = $release.assets | Where-Object { $_.name -match $arch -and $_.name -match '\.zip$' } | Select-Object -First 1
                if (-not $asset) { throw '未找到适配的官方 CLI 资产，请先安装 Node.js 后重试' }
                $dlUrl = $asset.browser_download_url
                if ($cfg.GitHubProxy) { $dlUrl = $cfg.GitHubProxy.TrimEnd('/') + '/' + $dlUrl }
                $tmpZip = Join-Path $env:TEMP ('codex-' + [guid]::NewGuid().ToString('N') + '.zip')
                Invoke-WebRequest -Uri $dlUrl -OutFile $tmpZip -UseBasicParsing -TimeoutSec 600
                $tmpDir = Join-Path $env:TEMP ('codex-unzip-' + [guid]::NewGuid().ToString('N'))
                Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmpDir -Force
                $exe = Get-ChildItem -LiteralPath $tmpDir -Recurse -Filter '*.exe' | Select-Object -First 1
                if (-not $exe) { throw '压缩包中未找到 codex 可执行文件' }
                Copy-Item -LiteralPath $exe.FullName -Destination $localCli -Force
                Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
                $cliPath = $localCli
                Log ('CLI 已装入专属目录: ' + $localCli + '（未修改全局 PATH）')
            }
        }
        try {
            $ver = (& $cliPath --version 2>&1 | Out-String).Trim()
            if ($ver) { Log ('CLI 版本: ' + $ver); $sync.Summary.Version = $ver }
        } catch {}
        $sync.Summary.CliPath = $cliPath

        # 3. 可选复用本机 Codex Desktop。此操作只在用户电脑本地复制，发布物不包含官方二进制。
        $desktopExe = $null
        if ($cfg.BundleDesktop) {
            Stage '查找已安装的 Codex Desktop' 30
            $candidates = New-Object System.Collections.Generic.List[string]
            foreach ($p in @(
                (Join-Path $env:LOCALAPPDATA 'Programs\Codex'),
                (Join-Path $env:LOCALAPPDATA 'Programs\codex'),
                (Join-Path $env:LOCALAPPDATA 'Programs\Codex Desktop'),
                (Join-Path $env:ProgramFiles 'Codex')
            )) { if ($p) { $candidates.Add($p) } }
            foreach ($regRoot in @(
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
                'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
            )) {
                Get-ChildItem $regRoot -ErrorAction SilentlyContinue | ForEach-Object {
                    $ip = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    if ($ip.DisplayName -and $ip.DisplayName -match '^Codex') {
                        if ($ip.InstallLocation) { $candidates.Add([string]$ip.InstallLocation) }
                        elseif ($ip.DisplayIcon) { $candidates.Add((Split-Path ([string]$ip.DisplayIcon -replace '",.*$', '' -replace '^"', '') -Parent)) }
                    }
                }
            }
            $sourceDir = $null
            foreach ($cand in ($candidates | Select-Object -Unique)) {
                if ([string]::IsNullOrWhiteSpace($cand)) { continue }
                if (-not (Test-Path -LiteralPath $cand)) { continue }
                $marker = (Test-Path -LiteralPath (Join-Path $cand 'resources\app.asar')) -or
                          (Test-Path -LiteralPath (Join-Path $cand 'resources\codex.exe'))
                $topExe = Get-ChildItem -LiteralPath $cand -Filter '*.exe' -ErrorAction SilentlyContinue |
                          Where-Object { $_.Name -notmatch 'uninstall|elevate|setup' } | Select-Object -First 1
                if ($marker -and $topExe) { $sourceDir = $cand; break }
            }
            if ($sourceDir) {
                Stage ('复制 Codex Desktop 为专属副本（源: ' + $sourceDir + '）') 34
                Log '原版安装不会被修改，只做文件复制，可能需要 1-3 分钟...'
                if (Test-Path -LiteralPath $appDir) {
                    $old = Join-Path $root ('app.old-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
                    Move-Item -LiteralPath $appDir -Destination $old -ErrorAction SilentlyContinue
                    if (Test-Path -LiteralPath $appDir) { Remove-Item -LiteralPath $appDir -Recurse -Force -ErrorAction SilentlyContinue }
                    else { Log ('旧副本已挪到: ' + $old) }
                }
                # 路径末尾的反斜杠会和结尾引号连成 \" —— Windows 命令行解析器把它当成
                # 转义引号，整条 robocopy 参数就此错位。注册表卸载项里的路径常带尾部反斜杠。
                $srcArg = $sourceDir.TrimEnd('\')
                $dstArg = $appDir.TrimEnd('\')
                $rc = Start-Process -FilePath 'robocopy.exe' -ArgumentList @('"' + $srcArg + '"', '"' + $dstArg + '"', '/E', '/NJH', '/NJS', '/NFL', '/NDL', '/R:1', '/W:1') -Wait -PassThru -WindowStyle Hidden
                if ($rc.ExitCode -ge 8) { throw ('复制 Codex Desktop 失败（robocopy 退出码 ' + $rc.ExitCode + '）') }
                $exeItem = Get-ChildItem -LiteralPath $appDir -Filter '*.exe' -ErrorAction SilentlyContinue |
                           Where-Object { $_.Name -notmatch 'uninstall|elevate|setup' } |
                           Sort-Object Length -Descending | Select-Object -First 1
                if ($exeItem) {
                    $desktopExe = $exeItem.FullName
                    Log ('专属桌面版就绪: ' + $desktopExe)
                    Log '提醒：请勿与官方 Codex Desktop 同时运行，二者会争抢应用数据目录'
                } else {
                    Log '副本中未找到主程序，回退为终端模式'
                }
            } else {
                Log '未检测到已安装的 Codex Desktop，本次为终端模式（可先安装官方桌面版再重跑本安装器）'
            }
        }
        $sync.Summary.DesktopExe = $desktopExe

        # 4. 账号登录 / Key 解析
        Stage '获取访问凭证' 58
        $cred = Resolve-ApiKey
        $apiKey = $cred.ApiKey
        $baseUrl = $cred.BaseUrl

        # 5. 校验模型
        Stage '校验模型可用性' 66
        $model = $cfg.Model
        try {
            $ids = Get-Models -Key $apiKey -Base $baseUrl
            Log ('可用模型 ' + $ids.Count + ' 个')
            if ($ids.Count -gt 0 -and ($ids -notcontains $model)) {
                $auto = $ids | Where-Object { $_ -match 'codex' } | Select-Object -First 1
                if (-not $auto) { $auto = $ids[0] }
                Log ('所选模型 "' + $model + '" 不可用，已自动切换为: ' + $auto)
                $model = $auto
            }
        } catch {
            if ($_.Exception.Response) {
                try { if ([int]$_.Exception.Response.StatusCode -eq 401) { throw 'API Key 无效或已禁用（网关返回 401）' } } catch { if ($_.Exception.Message -match '401') { throw $_ } }
            }
            Log ('模型列表获取失败（' + $_.Exception.Message + '），继续安装')
        }
        $sync.Summary.Model = $model

        # 6. 写隔离配置（只写专属 codex-home，绝不碰 ~/.codex）
        Stage '写入隔离配置 (codex-home)' 76
        $configPath = Join-Path $codexHome 'config.toml'
        $lines = @(
            ('# 由 ' + $cfg.BrandName + ' Launcher 生成 · ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
            ('# 本文件位于独立 CODEX_HOME，不影响 ~/.codex'),
            ('model = "' + $model + '"'),
            ('model_provider = "' + $cfg.ProviderId + '"'),
            'preferred_auth_method = "apikey"',
            'disable_response_storage = true',
            '',
            ('[model_providers.' + $cfg.ProviderId + ']'),
            ('name = "' + $cfg.BrandName + '"'),
            ('base_url = "' + $baseUrl + '"'),
            'wire_api = "responses"',
            'requires_openai_auth = true'
        )
        Set-Content -LiteralPath $configPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
        $escaped = $apiKey.Replace('\', '\\').Replace('"', '\"')
        Set-Content -LiteralPath (Join-Path $codexHome 'auth.json') -Value ('{"OPENAI_API_KEY":"' + $escaped + '"}') -Encoding ASCII
        Log ('配置与凭证已写入: ' + $codexHome)
        $sync.Summary.ConfigPath = $configPath

        # 7. 生成启动器 + 桌面快捷方式
        Stage '生成启动器与快捷方式' 84
        $terminalCmd = Join-Path $root ($cfg.BrandName + ' Codex 终端.cmd')
        $cliDirForPath = Split-Path $cliPath -Parent
        $tLines = @(
            '@echo off',
            ('set "CODEX_HOME=' + $codexHome + '"'),
            ('set "CODEX_INSTALL_DIR=' + $binDir + '"'),
            ('set "PATH=' + $binDir + ';' + $cliDirForPath + ';%PATH%"'),
            ('title ' + $cfg.BrandName + ' Codex'),
            ('echo [' + $cfg.BrandName + '] Codex 已连接 ' + $cfg.BrandName + ' 网关（独立 CODEX_HOME）'),
            'codex %*',
            'if errorlevel 1 pause'
        )
        # cmd 批处理按系统 ANSI 代码页解析，用 Default 编码写入以保住中文横幅与中文路径
        Set-Content -LiteralPath $terminalCmd -Value ($tLines -join "`r`n") -Encoding Default
        $launchTarget = $terminalCmd
        $desktopCmd = $null
        if ($desktopExe) {
            $desktopCmd = Join-Path $root ($cfg.BrandName + ' Codex.cmd')
            $dLines = @(
                '@echo off',
                ('set "CODEX_HOME=' + $codexHome + '"'),
                ('set "CODEX_INSTALL_DIR=' + $binDir + '"'),
                ('start "" "' + $desktopExe + '"')
            )
            Set-Content -LiteralPath $desktopCmd -Value ($dLines -join "`r`n") -Encoding Default
            $launchTarget = $desktopCmd
        }
        $desktopDir = [Environment]::GetFolderPath('Desktop')
        if ([string]::IsNullOrWhiteSpace($desktopDir) -or -not (Test-Path -LiteralPath $desktopDir)) { $desktopDir = $null }
        $uninstallCmd = Join-Path $root '卸载.cmd'
        $uLines = @(
            '@echo off',
            'echo Removing ' + $cfg.BrandName + ' Codex Launcher (your official Codex is untouched)...'
        )
        if ($desktopDir) {
            $uLines += ('del "' + (Join-Path $desktopDir ($cfg.BrandName + ' Codex.lnk')) + '" 2>nul')
            $uLines += ('del "' + (Join-Path $desktopDir ($cfg.BrandName + ' Codex 终端.lnk')) + '" 2>nul')
        }
        # 必须用 cmd /s /c：/s 让 cmd 只剥掉最外层引号、其余原样执行，路径含空格时
        # 才不会被拆断。旧写法用 ""路径""" 三层引号，含空格的安装路径下删不掉目录。
        $uLines += ('start "" cmd /s /c "timeout /t 2 >nul & rd /s /q "' + $root + '""')
        Set-Content -LiteralPath $uninstallCmd -Value ($uLines -join "`r`n") -Encoding Default

        $shortcuts = @()
        if ($desktopDir) {
            $wsh = New-Object -ComObject WScript.Shell
            if ($desktopCmd) {
                $lnk = $wsh.CreateShortcut((Join-Path $desktopDir ($cfg.BrandName + ' Codex.lnk')))
                $lnk.TargetPath = $desktopCmd
                $lnk.WorkingDirectory = $root
                $lnk.IconLocation = ($desktopExe + ',0')
                $lnk.Description = ($cfg.BrandName + ' Codex 桌面版（独立配置）')
                $lnk.Save()
                $shortcuts += ($cfg.BrandName + ' Codex —— 桌面版（专属副本）')
            }
            $lnk2 = $wsh.CreateShortcut((Join-Path $desktopDir ($cfg.BrandName + ' Codex 终端.lnk')))
            $lnk2.TargetPath = $terminalCmd
            $lnk2.WorkingDirectory = [Environment]::GetFolderPath('UserProfile')
            if ($desktopExe) { $lnk2.IconLocation = ($desktopExe + ',0') }
            $lnk2.Description = ($cfg.BrandName + ' Codex 终端（独立配置）')
            $lnk2.Save()
            $shortcuts += ($cfg.BrandName + ' Codex 终端 —— 命令行版')
        }
        $sync.Summary.LaunchTarget = $launchTarget
        $sync.Summary.Shortcuts = ($shortcuts -join [Environment]::NewLine)
        Log '桌面快捷方式已创建'
        Set-Content -LiteralPath (Join-Path $root 'installed.txt') -Value ((Get-Date).ToString('o') + [Environment]::NewLine + $cfg.BrandName + ' Launcher ' + $cfg.AppVersion) -Encoding UTF8

        # 8. 冒烟测试
        if ($cfg.Smoke) {
            Stage ('连通性测试（模型: ' + $model + '）') 92
            try {
                $headers = @{ Authorization = ('Bearer ' + $apiKey); 'Content-Type' = 'application/json' }
                $body = '{"model":"' + $model + '","input":"Reply only OK.","max_output_tokens":16}'
                $null = Invoke-RestMethod -Uri ($baseUrl.TrimEnd('/') + '/responses') -Method Post -Headers $headers -Body $body -TimeoutSec 120
                Log '网关 /responses 转发正常'
            } catch {
                Log ('连通性测试未通过: ' + $_.Exception.Message)
                Log '常见原因：模型未在渠道开通。可在控制台调整，无需重装。'
            }
        }

        Stage '安装完成' 100
        $sync.Success = $true
    } catch {
        Log ('安装失败: ' + $_.Exception.Message)
        $sync.Summary.Error = $_.Exception.Message
        $sync.Success = $false
    }
    $sync.Done = $true
}

$script:psWorker = $null
$script:rsWorker = $null
function Start-Worker([string]$Mode) {
    $authMode = 'account'
    if ($ModeApiKey.IsChecked) { $authMode = 'key' }
    $key = if ($KeyBoxPlain.Visibility -eq 'Visible') { $KeyBoxPlain.Text.Trim() } else { $KeyBox.Password.Trim() }
    $cfg = @{
        Mode = $Mode; AuthMode = $authMode
        Username = $UserBox.Text.Trim(); Password = $PassBox.Password
        ApiKey = $key
        Model = $ModelBox.Text.Trim()
        Smoke = ($ChkSmoke.IsChecked -eq $true)
        BundleDesktop = ($ChkDesktop.IsChecked -eq $true)
        BrandName = $BrandName; ProviderId = $ProviderId
        GatewayBaseUrl = $GatewayBaseUrl; SiteBaseUrl = $SiteBaseUrl
        GitHubProxy = $GitHubProxy; NpmMirror = $NpmMirror
        LauncherRoot = $LauncherRoot; AppVersion = $AppVersion
    }
    $sync.Running = $true; $sync.Done = $false; $sync.Success = $false
    $sync.Progress = 0; $sync.Stage = '准备中...'; $sync.ModelsFetched = $false
    $script:rsWorker = [runspacefactory]::CreateRunspace()
    $script:rsWorker.Open()
    $script:psWorker = [powershell]::Create()
    $script:psWorker.Runspace = $script:rsWorker
    [void]$script:psWorker.AddScript($workerScript).AddArgument($sync).AddArgument($cfg)
    [void]$script:psWorker.BeginInvoke()
}

function Test-FormInput {
    if ($ModeApiKey.IsChecked) {
        $key = if ($KeyBoxPlain.Visibility -eq 'Visible') { $KeyBoxPlain.Text.Trim() } else { $KeyBox.Password.Trim() }
        if ([string]::IsNullOrWhiteSpace($key)) { $FormStatus.Text = '请先粘贴 API Key'; return $false }
    } else {
        if ([string]::IsNullOrWhiteSpace($UserBox.Text) -or [string]::IsNullOrWhiteSpace($PassBox.Password)) {
            $FormStatus.Text = '请输入账号和密码（或切换到 API Key 模式）'; return $false
        }
    }
    $FormStatus.Text = ''
    return $true
}

# ---------------------------------------------------------------------------
# UI 交互
# ---------------------------------------------------------------------------
$TitleBar.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })
$BtnClose.Add_Click({ $window.Close() })
$BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
$BtnGetKey.Add_Click({ Start-Process $SiteBaseUrl })
$ModeAccount.Add_Checked({ if ($AccountFields) { $AccountFields.Visibility = 'Visible'; $KeyFields.Visibility = 'Collapsed' } })
$ModeApiKey.Add_Checked({ if ($KeyFields) { $KeyFields.Visibility = 'Visible'; $AccountFields.Visibility = 'Collapsed' } })
$BtnEye.Add_Click({
    if ($KeyBoxPlain.Visibility -eq 'Visible') {
        $KeyBox.Password = $KeyBoxPlain.Text
        $KeyBoxPlain.Visibility = 'Collapsed'; $KeyBox.Visibility = 'Visible'
    } else {
        $KeyBoxPlain.Text = $KeyBox.Password
        $KeyBox.Visibility = 'Collapsed'; $KeyBoxPlain.Visibility = 'Visible'
    }
})

$BtnValidate.Add_Click({
    if ($sync.Running) { return }
    if (-not (Test-FormInput)) { return }
    $ModelHint.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0x8B, 0x94, 0x9E))
    $ModelHint.Text = '正在验证并拉取模型列表...'
    Start-Worker -Mode 'validate'
})

$BtnInstall.Add_Click({
    if ($sync.Running) { return }
    if (-not (Test-FormInput)) { return }
    $PanelForm.Visibility = 'Collapsed'
    $PanelProgress.Visibility = 'Visible'
    $LogBox.Text = ''
    Start-Worker -Mode 'install'
})

$BtnOpenDir.Add_Click({ if (Test-Path $LauncherRoot) { Start-Process explorer.exe $LauncherRoot } })
$BtnLaunch.Add_Click({
    $t = $sync.Summary.LaunchTarget
    if ($t -and (Test-Path -LiteralPath $t)) { Start-Process -FilePath $t -WorkingDirectory $LauncherRoot }
})
$BtnFinish.Add_Click({ $window.Close() })

# ---------------------------------------------------------------------------
# UI 刷新计时器
# ---------------------------------------------------------------------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    while ($sync.Log.Count -gt 0) {
        $line = $sync.Log.Dequeue()
        $LogBox.AppendText($line + [Environment]::NewLine)
        $LogScroll.ScrollToEnd()
    }
    if ($PanelProgress.Visibility -eq 'Visible') {
        $StageText.Text = $sync.Stage
        $pct = [Math]::Max(0, [Math]::Min(100, $sync.Progress))
        $PctText.Text = ($pct.ToString() + '%')
        $ProgFill.Width = 556.0 * $pct / 100.0
    }
    if ($sync.Done) {
        $sync.Done = $false; $sync.Running = $false
        try { if ($script:psWorker) { $script:psWorker.Dispose() }; if ($script:rsWorker) { $script:rsWorker.Dispose() } } catch {}

        if ($sync.ModelsFetched) {
            $ids = $sync.ModelIds
            if ($sync.Success -and $ids -and $ids.Count -gt 0) {
                $current = $ModelBox.Text
                $ModelBox.Items.Clear()
                foreach ($id in $ids) { [void]$ModelBox.Items.Add($id) }
                $pick = $null
                if ($ids -contains $current) { $pick = $current }
                if (-not $pick) { $pick = ($ids | Where-Object { $_ -match 'codex' } | Select-Object -First 1) }
                if (-not $pick) { $pick = $ids[0] }
                $ModelBox.SelectedItem = $pick
                $ModelHint.Text = ('√ 验证通过，共 ' + $ids.Count + ' 个可用模型，已选中推荐项')
                $ModelHint.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0x3F, 0xB9, 0x50))
            } else {
                $ModelHint.Text = '验证失败'
                $ModelHint.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xF8, 0x51, 0x49))
                $FormStatus.Text = [string]$sync.Summary.Error
            }
            $sync.ModelsFetched = $false
            return
        }

        if ($PanelProgress.Visibility -eq 'Visible') {
            if ($sync.Success) {
                $PanelProgress.Visibility = 'Collapsed'
                $PanelDone.Visibility = 'Visible'
                $m = $sync.Summary.Model
                $sub = '模型: ' + $m + '   ·   安装位置: ' + $LauncherRoot
                if (-not $sync.Summary.DesktopExe) { $sub = $sub + [Environment]::NewLine + '（本次使用终端模式）' }
                $DoneSub.Text = $sub
                $DoneShortcuts.Text = [string]$sync.Summary.Shortcuts
            } else {
                $StageText.Text = '安装失败'
                $StageText.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xF8, 0x51, 0x49))
                if (-not $script:retryAdded) {
                    $script:retryAdded = $true
                    $back = New-Object System.Windows.Controls.Button
                    $back.Content = '← 返回修改后重试'
                    $back.Style = $window.FindResource('GhostBtn')
                    $back.Margin = New-Object System.Windows.Thickness(0, 12, 0, 0)
                    $back.Add_Click({
                        $PanelProgress.Visibility = 'Collapsed'
                        $PanelForm.Visibility = 'Visible'
                        $StageText.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(0xE6, 0xED, 0xF3))
                    })
                    [void]$PanelProgress.Children.Add($back)
                }
            }
        }
    }
})
$timer.Start()

[void]$window.ShowDialog()
$timer.Stop()
try { if ($script:psWorker) { $script:psWorker.Dispose() }; if ($script:rsWorker) { $script:rsWorker.Dispose() } } catch {}
