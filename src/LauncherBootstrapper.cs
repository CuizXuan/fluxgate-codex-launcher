using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;

namespace FluxGate.CodexLauncher
{
    internal static class Program
    {
        private const string ResourceName = "FluxGate.CodexLauncher.SetupScript";

        [STAThread]
        private static int Main(string[] args)
        {
            using (Stream script = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourceName))
            {
                if (script == null || script.Length < 1024)
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

                try
                {
                    using (FileStream output = File.Create(tempScript))
                    {
                        script.CopyTo(output);
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
                    }
                    catch
                    {
                    }
                }
            }
        }
    }
}
