using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;

namespace FluxGate.CodexLauncher
{
    internal static class Program
    {
        private const string SetupResourceName = "FluxGate.CodexLauncher.SetupScript";
        private const string CompanionResourceName = "FluxGate.CodexLauncher.Companion";

        [STAThread]
        private static int Main(string[] args)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream script = assembly.GetManifestResourceStream(SetupResourceName))
            using (Stream companion = assembly.GetManifestResourceStream(CompanionResourceName))
            {
                if (script == null || script.Length < 1024 || companion == null || companion.Length < 1024)
                {
                    return 2;
                }

                if (args.Any(arg => string.Equals(arg, "--self-test", StringComparison.OrdinalIgnoreCase)))
                {
                    return 0;
                }

                string tempScript = Path.Combine(
                    Path.GetTempPath(),
                    "FluxGate-Codex-Setup-" + Guid.NewGuid().ToString("N") + ".ps1");
                string tempCompanion = Path.Combine(
                    Path.GetTempPath(),
                    "FluxGate-Codex-Companion-" + Guid.NewGuid().ToString("N") + ".exe");

                try
                {
                    using (FileStream output = File.Create(tempScript))
                    {
                        script.CopyTo(output);
                    }
                    using (FileStream output = File.Create(tempCompanion))
                    {
                        companion.CopyTo(output);
                    }

                    string powershell = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.System),
                        "WindowsPowerShell",
                        "v1.0",
                        "powershell.exe");

                    var startInfo = new ProcessStartInfo
                    {
                        FileName = powershell,
                        Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + tempScript + "\"",
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory
                    };
                    startInfo.EnvironmentVariables["FLUXGATE_COMPANION_SOURCE"] = tempCompanion;

                    using (Process process = Process.Start(startInfo))
                    {
                        if (process == null)
                        {
                            return 3;
                        }
                        process.WaitForExit();
                        return process.ExitCode;
                    }
                }
                catch
                {
                    return 4;
                }
                finally
                {
                    try
                    {
                        if (File.Exists(tempScript))
                        {
                            File.Delete(tempScript);
                        }
                        if (File.Exists(tempCompanion))
                        {
                            File.Delete(tempCompanion);
                        }
                    }
                    catch
                    {
                    }
                }
            }
        }
    }
}
