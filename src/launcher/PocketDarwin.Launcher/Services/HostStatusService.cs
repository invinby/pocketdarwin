using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace PocketDarwin.Launcher.Services;

public sealed class HostStatusService(IProcessRunner runner)
{
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetPhysicallyInstalledSystemMemory(out long totalMemoryInKilobytes);

    public async Task<HostInfo> GetHostInfoAsync(CancellationToken cancellationToken)
    {
        var errors = new List<string>();
        var cpu = Registry.GetValue(@"HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\CentralProcessor\0", "ProcessorNameString", null)?.ToString() ?? "Unknown";
        var ram = GetPhysicallyInstalledSystemMemory(out var kibibytes) ? kibibytes * 1024 : GC.GetGCMemoryInfo().TotalAvailableMemoryBytes;
        var result = await runner.RunAsync("wsl.exe", ["--list", "--verbose"], cancellationToken);
        if (result.ExitCode != 0)
        {
            errors.Add("WSL_NOT_INSTALLED");
            return new HostInfo(Environment.OSVersion.Version.Build.ToString(), RuntimeInformation.OSArchitecture.ToString(), cpu, ram, false, null, null, null, false, null, errors);
        }

        string? distro = null;
        string? state = null;
        int? version = null;
        foreach (var raw in result.StandardOutput.Replace("\0", "").Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            var line = raw.Trim().TrimStart('*').Trim();
            var parts = line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 3 || !int.TryParse(parts[^1], out var parsedVersion)) continue;
            distro = parts[0];
            state = string.Join(' ', parts.Skip(1).SkipLast(1));
            version = parsedVersion;
            break;
        }

        if (distro is null) errors.Add("WSL_DISTRO_NOT_FOUND");
        else if (version != 2) errors.Add("WSL2_REQUIRED");
        else if (!string.Equals(state, "Running", StringComparison.OrdinalIgnoreCase)) errors.Add("WSL_DISTRO_STOPPED");

        var wslg = false;
        long? free = null;
        if (distro is not null && version == 2 && string.Equals(state, "Running", StringComparison.OrdinalIgnoreCase))
        {
            var probe = await runner.RunAsync("wsl.exe", ["-d", distro, "--", "bash", "-lc", "printf '%s\\n' \"${WAYLAND_DISPLAY:-}\" \"${DISPLAY:-}\"; df -Pk / | awk 'NR==2 {print $4}'"], cancellationToken);
            if (probe.ExitCode == 0)
            {
                var lines = probe.StandardOutput.Replace("\0", "").Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                wslg = lines.Length >= 3 && lines[0].Length > 0 && lines[1].Length > 0;
                if (lines.Length >= 3 && long.TryParse(lines[^1], out var diskKibibytes)) free = diskKibibytes * 1024;
            }
            if (!wslg) errors.Add("WSLG_UNAVAILABLE");
        }

        return new HostInfo(Environment.OSVersion.Version.Build.ToString(), RuntimeInformation.OSArchitecture.ToString(), cpu, ram, true, version, distro, state, wslg, free, errors);
    }
}
