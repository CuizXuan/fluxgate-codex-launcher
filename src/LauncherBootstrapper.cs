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
        private const string CodexArchiveResourceName = "FluxGate.CodexLauncher.OfficialCodexArchive";
        private const string NoticeResourceName = "FluxGate.CodexLauncher.Notice";
        private const string ThirdPartyLicensesResourceName = "FluxGate.CodexLauncher.ThirdPartyLicenses";

        [STAThread]
        private static int Main(string[] args)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream script = assembly.GetManifestResourceStream(SetupResourceName))
            using (Stream companion = assembly.GetManifestResourceStream(CompanionResourceName))
            using (Stream codexArchive = assembly.GetManifestResourceStream(CodexArchiveResourceName))
            using (Stream notice = assembly.GetManifestResourceStream(NoticeResourceName))
            using (Stream thirdPartyLicenses = assembly.GetManifestResourceStream(ThirdPartyLicensesResourceName))
            {
                if (script == null || script.Length < 1024 ||
                    companion == null || companion.Length < 1024 ||
                    notice == null || notice.Length < 1024 ||
                    thirdPartyLicenses == null || thirdPartyLicenses.Length < 1024)
                {
                    return 2;
                }

                bool requireFull = args.Any(arg => string.Equals(arg, "--self-test-full", StringComparison.OrdinalIgnoreCase));
                if (args.Any(arg => string.Equals(arg, "--self-test", StringComparison.OrdinalIgnoreCase)) || requireFull)
                {
                    if (requireFull && (codexArchive == null || codexArchive.Length < 50 * 1024 * 1024))
                    {
                        return 5;
                    }
                    return 0;
                }

                string tempScript = Path.Combine(
                    Path.GetTempPath(),
                    "FluxGate-Codex-Setup-" + Guid.NewGuid().ToString("N") + ".ps1");
                string tempCompanion = Path.Combine(
                    Path.GetTempPath(),
                    "FluxGate-Codex-Companion-" + Guid.NewGuid().ToString("N") + ".exe");
                string tempCodexArchive = codexArchive == null
                    ? null
                    : Path.Combine(
                        Path.GetTempPath(),
                        "FluxGate-Official-Codex-" + Guid.NewGuid().ToString("N") + ".zip");
                string tempNotice = Path.Combine(
                    Path.GetTempPath(),
                    "FluxGate-NOTICE-" + Guid.NewGuid().ToString("N") + ".txt");
                string tempThirdPartyLicenses = Path.Combine(
                    Path.GetTempPath(),
                    "FluxGate-THIRD-PARTY-LICENSES-" + Guid.NewGuid().ToString("N") + ".md");

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
                    if (codexArchive != null)
                    {
                        using (FileStream output = File.Create(tempCodexArchive))
                        {
                            codexArchive.CopyTo(output);
                        }
                    }
                    using (FileStream output = File.Create(tempNotice))
                    {
                        notice.CopyTo(output);
                    }
                    using (FileStream output = File.Create(tempThirdPartyLicenses))
                    {
                        thirdPartyLicenses.CopyTo(output);
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
                    startInfo.EnvironmentVariables["FLUXGATE_NOTICE_SOURCE"] = tempNotice;
                    startInfo.EnvironmentVariables["FLUXGATE_THIRD_PARTY_LICENSES_SOURCE"] = tempThirdPartyLicenses;
                    if (tempCodexArchive != null)
                    {
                        startInfo.EnvironmentVariables["FLUXGATE_CODEX_ARCHIVE"] = tempCodexArchive;
                    }

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
                        if (tempCodexArchive != null && File.Exists(tempCodexArchive))
                        {
                            File.Delete(tempCodexArchive);
                        }
                        if (File.Exists(tempNotice))
                        {
                            File.Delete(tempNotice);
                        }
                        if (File.Exists(tempThirdPartyLicenses))
                        {
                            File.Delete(tempThirdPartyLicenses);
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
