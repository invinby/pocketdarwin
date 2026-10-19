namespace PocketDarwin.Launcher.Services;

public sealed record HostInfo(
    string WindowsBuild,
    string Architecture,
    string CpuName,
    long RamBytes,
    bool WslInstalled,
    int? WslVersion,
    string? DistroName,
    string? DistroState,
    bool WslgAvailable,
    long? FreeBytes,
    IReadOnlyList<string> Errors);
