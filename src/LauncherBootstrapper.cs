using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;

namespace FluxGate.CodexLauncher
{
    internal static class Program
    {
        private const string SetupResourceName = "FluxGate.CodexLauncher.SetupScript";
        private const string CompanionResourceName = "FluxGate.CodexLauncher.Companion";
        private const string CodexArchiveResourceName = "FluxGate.CodexLauncher.OfficialCodexArchive";
        private const string NoticeResourceName = "FluxGate.CodexLauncher.Notice";
        private const string ThirdPartyLicensesResourceName = "FluxGate.CodexLauncher.ThirdPartyLicenses";
        private const string PortableDesktopMagicText = "FLUXGATE_PORTABLE_DESKTOP_V1";
        private const int PortableDesktopDigestLength = 32;

        private static bool ReadExactly(Stream stream, byte[] buffer, int count)
        {
            int offset = 0;
            while (offset < count)
            {
                int read = stream.Read(buffer, offset, count - offset);
                if (read <= 0)
                {
                    return false;
                }
                offset += read;
            }
            return true;
        }

        private static bool TryReadPortableDesktopFooter(
            out long payloadOffset,
            out long payloadLength,
            out byte[] expectedDigest)
        {
            payloadOffset = 0;
            payloadLength = 0;
            expectedDigest = null;

            byte[] magic = Encoding.ASCII.GetBytes(PortableDesktopMagicText);
            int footerLength = sizeof(long) + PortableDesktopDigestLength + magic.Length;
            string executable = Assembly.GetExecutingAssembly().Location;
            using (FileStream input = new FileStream(
                executable,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read | FileShare.Delete))
            {
                if (input.Length <= footerLength)
                {
                    return false;
                }

                byte[] footer = new byte[footerLength];
                input.Seek(-footerLength, SeekOrigin.End);
                if (!ReadExactly(input, footer, footer.Length))
                {
                    return false;
                }

                int magicOffset = sizeof(long) + PortableDesktopDigestLength;
                for (int index = 0; index < magic.Length; index++)
                {
                    if (footer[magicOffset + index] != magic[index])
                    {
                        return false;
                    }
                }

                payloadLength = BitConverter.ToInt64(footer, 0);
                payloadOffset = input.Length - footerLength - payloadLength;
                if (payloadLength <= 0 || payloadOffset <= 0)
                {
                    payloadOffset = 0;
                    payloadLength = 0;
                    return false;
                }

                expectedDigest = new byte[PortableDesktopDigestLength];
                Buffer.BlockCopy(
                    footer,
                    sizeof(long),
                    expectedDigest,
                    0,
                    PortableDesktopDigestLength);
                return true;
            }
        }

        private static bool CopyAndVerifyPortableDesktopArchive(
            string destination,
            long payloadOffset,
            long payloadLength,
            byte[] expectedDigest)
        {
            Stream output = destination == null
                ? Stream.Null
                : (Stream)new FileStream(destination, FileMode.Create, FileAccess.Write, FileShare.None);
            try
            {
                using (FileStream input = new FileStream(
                    Assembly.GetExecutingAssembly().Location,
                    FileMode.Open,
                    FileAccess.Read,
                    FileShare.Read | FileShare.Delete))
                using (SHA256 sha256 = SHA256.Create())
                {
                    input.Seek(payloadOffset, SeekOrigin.Begin);
                    byte[] buffer = new byte[1024 * 1024];
                    long remaining = payloadLength;
                    while (remaining > 0)
                    {
                        int requested = (int)Math.Min(buffer.Length, remaining);
                        int read = input.Read(buffer, 0, requested);
                        if (read <= 0)
                        {
                            return false;
                        }
                        output.Write(buffer, 0, read);
                        sha256.TransformBlock(buffer, 0, read, buffer, 0);
                        remaining -= read;
                    }
                    sha256.TransformFinalBlock(new byte[0], 0, 0);
                    return sha256.Hash.SequenceEqual(expectedDigest);
                }
            }
            finally
            {
                output.Dispose();
                if (destination != null && File.Exists(destination))
                {
                    FileInfo file = new FileInfo(destination);
                    if (file.Length != payloadLength)
                    {
                        File.Delete(destination);
                    }
                }
            }
        }

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
                bool requirePortable = args.Any(arg => string.Equals(arg, "--self-test-portable", StringComparison.OrdinalIgnoreCase));
                if (args.Any(arg => string.Equals(arg, "--self-test", StringComparison.OrdinalIgnoreCase)) || requireFull || requirePortable)
                {
                    if ((requireFull || requirePortable) && (codexArchive == null || codexArchive.Length < 50 * 1024 * 1024))
                    {
                        return 5;
                    }
                    if (requirePortable)
                    {
                        long payloadOffset;
                        long payloadLength;
                        byte[] expectedDigest;
                        if (!TryReadPortableDesktopFooter(out payloadOffset, out payloadLength, out expectedDigest))
                        {
                            return 6;
                        }
                        if (!CopyAndVerifyPortableDesktopArchive(null, payloadOffset, payloadLength, expectedDigest))
                        {
                            return 7;
                        }
                    }
                    return 0;
                }

                long portableDesktopOffset;
                long portableDesktopLength;
                byte[] portableDesktopDigest;
                bool hasPortableDesktop = TryReadPortableDesktopFooter(
                    out portableDesktopOffset,
                    out portableDesktopLength,
                    out portableDesktopDigest);

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
                string tempPortableDesktopArchive = hasPortableDesktop
                    ? Path.Combine(
                        Path.GetTempPath(),
                        "FluxGate-Portable-Desktop-" + Guid.NewGuid().ToString("N") + ".zip")
                    : null;

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
                    if (hasPortableDesktop && !CopyAndVerifyPortableDesktopArchive(
                        tempPortableDesktopArchive,
                        portableDesktopOffset,
                        portableDesktopLength,
                        portableDesktopDigest))
                    {
                        return 7;
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
                    if (tempPortableDesktopArchive != null)
                    {
                        startInfo.EnvironmentVariables["FLUXGATE_DESKTOP_ARCHIVE"] = tempPortableDesktopArchive;
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
                        if (tempPortableDesktopArchive != null && File.Exists(tempPortableDesktopArchive))
                        {
                            File.Delete(tempPortableDesktopArchive);
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
