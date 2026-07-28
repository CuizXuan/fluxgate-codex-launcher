using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace FluxGate.CodexLauncher
{
    internal static class CompanionProgram
    {
        [STAThread]
        private static int Main(string[] args)
        {
            if (Array.Exists(args, arg => string.Equals(arg, "--self-test", StringComparison.OrdinalIgnoreCase)))
            {
                return CompanionConfig.SelfTest() ? 0 : 2;
            }

            bool ownsMutex;
            string mutexName = Environment.GetEnvironmentVariable("FLUXGATE_COMPANION_MUTEX");
            if (string.IsNullOrWhiteSpace(mutexName)) mutexName = "Local\\FluxGateAI-Codex-Companion";
            using (var mutex = new Mutex(true, mutexName, out ownsMutex))
            {
                if (!ownsMutex)
                {
                    return 0;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                using (var context = new CompanionContext())
                {
                    Application.Run(context);
                }
            }
            return 0;
        }
    }

    internal sealed class CompanionConfig
    {
        public string SiteBaseUrl { get; set; }
        public string CodexHome { get; set; }
        public string CodexBin { get; set; }
        public string Workdir { get; set; }
        public string DeviceId { get; set; }
        public string DeviceName { get; set; }
        public int MaxRunMs { get; set; }

        public static CompanionConfig Load(string path)
        {
            var serializer = new JavaScriptSerializer();
            CompanionConfig config = File.Exists(path)
                ? serializer.Deserialize<CompanionConfig>(File.ReadAllText(path, Encoding.UTF8))
                : new CompanionConfig();
            string root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "FluxGateAICodexLauncher");
            if (string.IsNullOrWhiteSpace(config.SiteBaseUrl)) config.SiteBaseUrl = "https://api.fluxapi.cloud";
            if (string.IsNullOrWhiteSpace(config.CodexHome)) config.CodexHome = Path.Combine(root, "codex-home");
            if (string.IsNullOrWhiteSpace(config.CodexBin)) config.CodexBin = "codex";
            if (string.IsNullOrWhiteSpace(config.Workdir) || !Directory.Exists(config.Workdir))
            {
                config.Workdir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            }
            if (string.IsNullOrWhiteSpace(config.DeviceId)) config.DeviceId = Guid.NewGuid().ToString();
            if (string.IsNullOrWhiteSpace(config.DeviceName)) config.DeviceName = Environment.MachineName;
            if (config.MaxRunMs < 60000) config.MaxRunMs = 10 * 60 * 1000;
            return config;
        }

        public void Save(string path)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllText(path, new JavaScriptSerializer().Serialize(this), new UTF8Encoding(false));
        }

        public static bool SelfTest()
        {
            var serializer = new JavaScriptSerializer();
            var source = new CompanionConfig
            {
                SiteBaseUrl = "https://example.test",
                CodexHome = "C:\\CodexHome",
                CodexBin = "codex",
                Workdir = "C:\\Workspace",
                DeviceId = "device",
                DeviceName = "desktop",
                MaxRunMs = 60000
            };
            CompanionConfig roundTrip = serializer.Deserialize<CompanionConfig>(serializer.Serialize(source));
            return roundTrip != null && roundTrip.DeviceId == "device" && roundTrip.MaxRunMs == 60000;
        }
    }

    internal sealed class BridgeMessage
    {
        public string type { get; set; }
        public string session_id { get; set; }
        public string device_id { get; set; }
        public string prompt { get; set; }
        public string data { get; set; }
        public string stream { get; set; }
        public string message { get; set; }
        public int? exit_code { get; set; }
    }

    internal sealed class CompanionContext : ApplicationContext, IDisposable
    {
        private readonly string root;
        private readonly string configPath;
        private readonly string logPath;
        private readonly CompanionConfig config;
        private readonly NotifyIcon tray;
        private readonly Control dispatcher;
        private readonly ToolStripMenuItem statusItem;
        private readonly ToolStripMenuItem startupItem;
        private readonly CancellationTokenSource lifetime = new CancellationTokenSource();
        private readonly SemaphoreSlim sendLock = new SemaphoreSlim(1, 1);
        private readonly JavaScriptSerializer serializer = new JavaScriptSerializer();
        private readonly object sessionsLock = new object();
        private readonly Dictionary<string, Process> sessions = new Dictionary<string, Process>();
        private ClientWebSocket socket;
        private bool disposed;
        private bool onlineNotificationShown;

        public CompanionContext()
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            root = Environment.GetEnvironmentVariable("FLUXGATE_COMPANION_ROOT");
            if (string.IsNullOrWhiteSpace(root))
            {
                root = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                    "FluxGateAICodexLauncher");
            }
            root = Path.GetFullPath(root);
            configPath = Path.Combine(root, "companion.json");
            logPath = Path.Combine(root, "logs", "companion.log");
            Directory.CreateDirectory(Path.GetDirectoryName(logPath));
            config = CompanionConfig.Load(configPath);
            config.Save(configPath);
            dispatcher = new Control();
            IntPtr dispatcherHandle = dispatcher.Handle;
            if (dispatcherHandle == IntPtr.Zero) throw new InvalidOperationException("Unable to create the tray dispatcher.");

            statusItem = new ToolStripMenuItem("正在连接...") { Enabled = false };
            startupItem = new ToolStripMenuItem("开机自动运行")
            {
                Checked = StartupShortcutExists(),
                CheckOnClick = true
            };
            startupItem.Click += delegate { SetStartupEnabled(startupItem.Checked); };

            var chooseFolder = new ToolStripMenuItem("选择项目目录...");
            chooseFolder.Click += delegate { ChooseWorkdir(); };
            var openMobile = new ToolStripMenuItem("打开手机端");
            openMobile.Click += delegate { OpenUrl(config.SiteBaseUrl.TrimEnd('/') + "/api/desktop/connect"); };
            var openLogs = new ToolStripMenuItem("打开日志");
            openLogs.Click += delegate { OpenPath(logPath); };
            var exit = new ToolStripMenuItem("退出");
            exit.Click += delegate { ExitThread(); };

            var menu = new ContextMenuStrip();
            menu.Items.Add(statusItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(chooseFolder);
            menu.Items.Add(openMobile);
            menu.Items.Add(openLogs);
            menu.Items.Add(startupItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(exit);

            Icon icon = null;
            try { icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            tray = new NotifyIcon
            {
                Icon = icon ?? SystemIcons.Application,
                Text = "FluxGateAI Codex",
                ContextMenuStrip = menu,
                Visible = true
            };
            tray.DoubleClick += delegate { OpenUrl(config.SiteBaseUrl.TrimEnd('/') + "/api/desktop/connect"); };
            Log("Companion started for device " + config.DeviceName + ".");
            Task.Run(() => ConnectLoopAsync(lifetime.Token));
        }

        protected override void ExitThreadCore()
        {
            lifetime.Cancel();
            KillAllSessions();
            try { if (socket != null) socket.Abort(); } catch { }
            tray.Visible = false;
            base.ExitThreadCore();
        }

        public new void Dispose()
        {
            if (disposed) return;
            disposed = true;
            lifetime.Cancel();
            KillAllSessions();
            if (socket != null) socket.Dispose();
            sendLock.Dispose();
            lifetime.Dispose();
            tray.Dispose();
            dispatcher.Dispose();
            base.Dispose();
        }

        private async Task ConnectLoopAsync(CancellationToken token)
        {
            int delayMs = 1000;
            while (!token.IsCancellationRequested)
            {
                try
                {
                    string apiKey = ReadApiKey();
                    using (var nextSocket = new ClientWebSocket())
                    {
                        nextSocket.Options.SetRequestHeader("Authorization", "Bearer " + apiKey);
                        socket = nextSocket;
                        SetStatus("正在连接...");
                        await nextSocket.ConnectAsync(BuildBridgeUri(), token).ConfigureAwait(false);
                        delayMs = 1000;
                        SetStatus("已连接 · " + config.DeviceName);
                        Log("Connected to Bridge gateway.");
                        ShowOnlineNotification();
                        await ReceiveLoopAsync(nextSocket, token).ConfigureAwait(false);
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception error)
                {
                    SetStatus("连接已断开，正在重试");
                    Log("Bridge connection error: " + CleanError(error));
                }
                finally
                {
                    socket = null;
                    KillAllSessions();
                }

                try
                {
                    await Task.Delay(delayMs, token).ConfigureAwait(false);
                    delayMs = Math.Min(delayMs * 2, 30000);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private Uri BuildBridgeUri()
        {
            var site = new Uri(config.SiteBaseUrl.TrimEnd('/'));
            var builder = new UriBuilder(site)
            {
                Scheme = string.Equals(site.Scheme, "https", StringComparison.OrdinalIgnoreCase) ? "wss" : "ws",
                Port = site.IsDefaultPort ? -1 : site.Port,
                Path = "/api/desktop/bridge/device",
                Query = "device_id=" + Uri.EscapeDataString(config.DeviceId)
                    + "&device_name=" + Uri.EscapeDataString(config.DeviceName)
            };
            return builder.Uri;
        }

        private async Task ReceiveLoopAsync(ClientWebSocket activeSocket, CancellationToken token)
        {
            var buffer = new byte[8192];
            while (activeSocket.State == WebSocketState.Open && !token.IsCancellationRequested)
            {
                using (var message = new MemoryStream())
                {
                    WebSocketReceiveResult result;
                    do
                    {
                        result = await activeSocket.ReceiveAsync(new ArraySegment<byte>(buffer), token).ConfigureAwait(false);
                        if (result.MessageType == WebSocketMessageType.Close)
                        {
                            return;
                        }
                        message.Write(buffer, 0, result.Count);
                        if (message.Length > 4 * 1024 * 1024)
                        {
                            throw new InvalidDataException("Bridge frame exceeded 4 MiB.");
                        }
                    } while (!result.EndOfMessage);

                    if (result.MessageType != WebSocketMessageType.Text) continue;
                    string json = Encoding.UTF8.GetString(message.ToArray());
                    BridgeMessage frame;
                    try { frame = serializer.Deserialize<BridgeMessage>(json); }
                    catch { continue; }
                    if (frame == null) continue;
                    if (frame.type == "exec") StartSession(frame, token);
                    else if (frame.type == "cancel") CancelSession(frame.session_id);
                }
            }
        }

        private void StartSession(BridgeMessage frame, CancellationToken lifetimeToken)
        {
            string sessionId = (frame.session_id ?? string.Empty).Trim();
            string prompt = (frame.prompt ?? string.Empty).Trim();
            if (sessionId.Length == 0 || prompt.Length == 0) return;
            lock (sessionsLock)
            {
                if (sessions.ContainsKey(sessionId))
                {
                    Task.Run(() => SendFrameAsync(new BridgeMessage
                    {
                        type = "error",
                        session_id = sessionId,
                        message = "该会话已有任务在执行"
                    }, lifetimeToken));
                    return;
                }
                sessions[sessionId] = null;
            }
            Log("Starting session " + ShortId(sessionId) + ".");
            Task.Run(() => RunCodexAsync(sessionId, prompt, lifetimeToken));
        }

        private async Task RunCodexAsync(string sessionId, string prompt, CancellationToken lifetimeToken)
        {
            Process process = null;
            Exception failure = null;
            try
            {
                LaunchSpec launch = ResolveCodexLaunch();
                var start = new ProcessStartInfo
                {
                    FileName = launch.FileName,
                    Arguments = launch.Arguments,
                    WorkingDirectory = Directory.Exists(config.Workdir)
                        ? config.Workdir
                        : Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                };
                start.EnvironmentVariables["CODEX_HOME"] = config.CodexHome;
                start.EnvironmentVariables["CODEX_INSTALL_DIR"] = Path.Combine(root, "codex-bin");
                string binDir = Path.GetDirectoryName(launch.FileName);
                if (!string.IsNullOrEmpty(binDir))
                {
                    start.EnvironmentVariables["PATH"] = binDir + ";" + start.EnvironmentVariables["PATH"];
                }

                process = new Process { StartInfo = start, EnableRaisingEvents = true };
                if (!process.Start()) throw new InvalidOperationException("Codex process did not start.");
                lock (sessionsLock) sessions[sessionId] = process;
                await process.StandardInput.WriteAsync(prompt).ConfigureAwait(false);
                process.StandardInput.Close();

                Task stdout = PumpOutputAsync(process.StandardOutput, sessionId, "stdout", lifetimeToken);
                Task stderr = PumpOutputAsync(process.StandardError, sessionId, "stderr", lifetimeToken);
                Task exited = Task.Run(() => process.WaitForExit());
                Task timeout = Task.Delay(config.MaxRunMs, lifetimeToken);
                Task completed = await Task.WhenAny(exited, timeout).ConfigureAwait(false);
                if (completed != exited)
                {
                    KillProcessTree(process);
                    if (lifetimeToken.IsCancellationRequested)
                    {
                        throw new OperationCanceledException(lifetimeToken);
                    }
                    throw new TimeoutException("Codex 任务执行超时");
                }
                await Task.WhenAll(stdout, stderr).ConfigureAwait(false);
                await SendFrameAsync(new BridgeMessage
                {
                    type = "done",
                    session_id = sessionId,
                    exit_code = process.ExitCode
                }, lifetimeToken).ConfigureAwait(false);
                Log("Session " + ShortId(sessionId) + " completed with exit code " + process.ExitCode + ".");
            }
            catch (OperationCanceledException)
            {
                if (process != null) KillProcessTree(process);
            }
            catch (Exception error)
            {
                if (process != null) KillProcessTree(process);
                failure = error;
            }
            finally
            {
                lock (sessionsLock) sessions.Remove(sessionId);
                if (process != null) process.Dispose();
            }
            if (failure != null)
            {
                await SendFrameAsync(new BridgeMessage
                {
                    type = "error",
                    session_id = sessionId,
                    message = "Codex 执行失败: " + CleanError(failure)
                }, lifetimeToken).ConfigureAwait(false);
                Log("Session " + ShortId(sessionId) + " failed: " + CleanError(failure));
            }
        }

        private async Task PumpOutputAsync(StreamReader reader, string sessionId, string stream, CancellationToken token)
        {
            var chars = new char[2048];
            while (!reader.EndOfStream && !token.IsCancellationRequested)
            {
                int count = await reader.ReadAsync(chars, 0, chars.Length).ConfigureAwait(false);
                if (count <= 0) break;
                await SendFrameAsync(new BridgeMessage
                {
                    type = "output",
                    session_id = sessionId,
                    data = new string(chars, 0, count),
                    stream = stream
                }, token).ConfigureAwait(false);
            }
        }

        private async Task SendFrameAsync(BridgeMessage frame, CancellationToken token)
        {
            ClientWebSocket activeSocket = socket;
            if (activeSocket == null || activeSocket.State != WebSocketState.Open) return;
            byte[] payload = Encoding.UTF8.GetBytes(serializer.Serialize(frame));
            await sendLock.WaitAsync(token).ConfigureAwait(false);
            try
            {
                if (activeSocket.State == WebSocketState.Open)
                {
                    await activeSocket.SendAsync(
                        new ArraySegment<byte>(payload),
                        WebSocketMessageType.Text,
                        true,
                        token).ConfigureAwait(false);
                }
            }
            finally
            {
                sendLock.Release();
            }
        }

        private LaunchSpec ResolveCodexLaunch()
        {
            string path = ResolveExecutable(config.CodexBin);
            if (string.IsNullOrEmpty(path)) throw new FileNotFoundException("未找到 Codex CLI，请重新运行 Launcher");
            string extension = Path.GetExtension(path).ToLowerInvariant();
            const string codexArgs = "exec --skip-git-repo-check -s workspace-write -";
            if (extension == ".exe") return new LaunchSpec(path, codexArgs);

            string shim = Path.Combine(
                Path.GetDirectoryName(path),
                "node_modules",
                "@openai",
                "codex",
                "bin",
                "codex.js");
            string node = ResolveExecutable("node");
            if (File.Exists(shim) && !string.IsNullOrEmpty(node))
            {
                return new LaunchSpec(node, Quote(shim) + " " + codexArgs);
            }
            if (extension == ".cmd" || extension == ".bat")
            {
                string command = "\"" + path + "\" " + codexArgs;
                return new LaunchSpec(Path.Combine(Environment.SystemDirectory, "cmd.exe"), "/d /s /c \"" + command + "\"");
            }
            throw new InvalidOperationException("无法安全启动 Codex CLI: " + path);
        }

        private static string ResolveExecutable(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return null;
            string expanded = Environment.ExpandEnvironmentVariables(value.Trim());
            if ((expanded.Contains("\\") || expanded.Contains("/")) && File.Exists(expanded)) return Path.GetFullPath(expanded);
            string[] extensions = string.IsNullOrEmpty(Path.GetExtension(expanded))
                ? new[] { ".exe", ".cmd", ".bat", ".ps1" }
                : new[] { string.Empty };
            foreach (string directory in (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(';'))
            {
                if (string.IsNullOrWhiteSpace(directory)) continue;
                foreach (string extension in extensions)
                {
                    try
                    {
                        string candidate = Path.Combine(directory.Trim(), expanded + extension);
                        if (File.Exists(candidate)) return candidate;
                    }
                    catch { }
                }
            }
            return null;
        }

        private string ReadApiKey()
        {
            string authPath = Path.Combine(config.CodexHome, "auth.json");
            if (!File.Exists(authPath)) throw new FileNotFoundException("未找到 Launcher 登录凭据，请重新运行 Launcher");
            var values = serializer.Deserialize<Dictionary<string, object>>(File.ReadAllText(authPath, Encoding.UTF8));
            object raw;
            string key = values != null && values.TryGetValue("OPENAI_API_KEY", out raw) ? Convert.ToString(raw) : string.Empty;
            if (string.IsNullOrWhiteSpace(key)) throw new InvalidDataException("Launcher 登录凭据无效，请重新运行 Launcher");
            return key.Trim();
        }

        private void CancelSession(string sessionId)
        {
            if (string.IsNullOrWhiteSpace(sessionId)) return;
            Process process;
            lock (sessionsLock) sessions.TryGetValue(sessionId, out process);
            if (process != null) KillProcessTree(process);
        }

        private void KillAllSessions()
        {
            Process[] active;
            lock (sessionsLock)
            {
                active = new List<Process>(sessions.Values).FindAll(item => item != null).ToArray();
                sessions.Clear();
            }
            foreach (Process process in active) KillProcessTree(process);
        }

        private static void KillProcessTree(Process process)
        {
            try
            {
                if (process == null || process.HasExited) return;
                Process.Start(new ProcessStartInfo
                {
                    FileName = Path.Combine(Environment.SystemDirectory, "taskkill.exe"),
                    Arguments = "/PID " + process.Id + " /T /F",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                });
            }
            catch
            {
                try { process.Kill(); } catch { }
            }
        }

        private void ChooseWorkdir()
        {
            using (var dialog = new FolderBrowserDialog
            {
                Description = "选择手机端 Codex 可以操作的项目目录",
                SelectedPath = config.Workdir,
                ShowNewFolderButton = false
            })
            {
                if (dialog.ShowDialog() != DialogResult.OK || !Directory.Exists(dialog.SelectedPath)) return;
                config.Workdir = dialog.SelectedPath;
                config.Save(configPath);
                tray.ShowBalloonTip(2500, "FluxGateAI Codex", "项目目录已切换为 " + config.Workdir, ToolTipIcon.Info);
                Log("Workdir changed to " + config.Workdir + ".");
            }
        }

        private void SetStatus(string text)
        {
            if (dispatcher.IsDisposed) return;
            try { dispatcher.BeginInvoke((MethodInvoker)delegate
            {
                statusItem.Text = text;
                tray.Text = text.Length <= 63 ? text : text.Substring(0, 63);
            }); } catch (InvalidOperationException) { }
        }

        private void ShowOnlineNotification()
        {
            if (onlineNotificationShown) return;
            onlineNotificationShown = true;
            if (dispatcher.IsDisposed) return;
            try { dispatcher.BeginInvoke((MethodInvoker)delegate
            {
                tray.ShowBalloonTip(3500, "FluxGateAI Codex 已就绪", "在手机 FluxAI 中打开“远程 Codex”即可使用。", ToolTipIcon.Info);
            }); } catch (InvalidOperationException) { }
        }

        private bool StartupShortcutExists()
        {
            return File.Exists(GetStartupShortcutPath());
        }

        private void SetStartupEnabled(bool enabled)
        {
            string shortcut = GetStartupShortcutPath();
            try
            {
                if (!enabled)
                {
                    if (File.Exists(shortcut)) File.Delete(shortcut);
                    return;
                }
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                dynamic shell = Activator.CreateInstance(shellType);
                dynamic link = shell.CreateShortcut(shortcut);
                link.TargetPath = Application.ExecutablePath;
                link.WorkingDirectory = root;
                link.Description = "FluxGateAI Codex background companion";
                link.Save();
            }
            catch (Exception error)
            {
                startupItem.Checked = StartupShortcutExists();
                tray.ShowBalloonTip(2500, "FluxGateAI Codex", "无法更新开机启动: " + CleanError(error), ToolTipIcon.Error);
            }
        }

        private string GetStartupShortcutPath()
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Startup),
                "FluxGateAI Codex Companion.lnk");
        }

        private static void OpenUrl(string url)
        {
            try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); } catch { }
        }

        private static void OpenPath(string path)
        {
            try
            {
                if (!File.Exists(path)) File.WriteAllText(path, string.Empty, Encoding.UTF8);
                Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
            }
            catch { }
        }

        private void Log(string message)
        {
            try
            {
                if (File.Exists(logPath) && new FileInfo(logPath).Length > 1024 * 1024)
                {
                    File.Copy(logPath, logPath + ".1", true);
                    File.WriteAllText(logPath, string.Empty, Encoding.UTF8);
                }
                File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + message + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
        }

        private static string Quote(string value)
        {
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }

        private static string ShortId(string value)
        {
            return value.Length <= 8 ? value : value.Substring(0, 8);
        }

        private static string CleanError(Exception error)
        {
            string message = error == null ? string.Empty : error.Message;
            return string.IsNullOrWhiteSpace(message) ? error.GetType().Name : message.Trim();
        }

        private sealed class LaunchSpec
        {
            public readonly string FileName;
            public readonly string Arguments;

            public LaunchSpec(string fileName, string arguments)
            {
                FileName = fileName;
                Arguments = arguments;
            }
        }
    }
}
