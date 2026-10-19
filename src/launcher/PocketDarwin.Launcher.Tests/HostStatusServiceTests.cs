using PocketDarwin.Launcher.Services;
using Xunit;

namespace PocketDarwin.Launcher.Tests;

public sealed class HostStatusServiceTests
{
    [Fact]
    public async Task Reports_missing_wsl_with_stable_error_without_writing()
    {
        var runner = new FakeProcessRunner(new ProcessResult(1, "", "wsl not found"));
        var service = new HostStatusService(runner);

        var result = await service.GetHostInfoAsync(CancellationToken.None);

        Assert.Contains("WSL_NOT_INSTALLED", result.Errors);
        Assert.Single(runner.Calls);
        Assert.Equal("wsl.exe", runner.Calls[0].FileName);
        Assert.DoesNotContain(runner.Calls, call => call.Arguments.Any(arg => arg is "--install" or "--unregister"));
    }

    [Fact]
    public async Task Reports_running_wsl2_distro_and_missing_wslg()
    {
        var runner = new FakeProcessRunner(
            new ProcessResult(0, "NAME STATE VERSION\n* Ubuntu Running 2", ""),
            new ProcessResult(0, "\n\n", ""));
        var service = new HostStatusService(runner);

        var result = await service.GetHostInfoAsync(CancellationToken.None);

        Assert.Equal("Ubuntu", result.DistroName);
        Assert.Equal("Running", result.DistroState);
        Assert.Equal(2, result.WslVersion);
        Assert.False(result.WslgAvailable);
        Assert.Contains("WSLG_UNAVAILABLE", result.Errors);
    }
}

internal sealed class FakeProcessRunner(params ProcessResult[] results) : IProcessRunner
{
    private readonly Queue<ProcessResult> _results = new(results);
    public List<ProcessCall> Calls { get; } = [];

    public Task<ProcessResult> RunAsync(string fileName, IReadOnlyList<string> arguments, CancellationToken cancellationToken)
    {
        Calls.Add(new ProcessCall(fileName, arguments.ToArray()));
        return Task.FromResult(_results.Dequeue());
    }
}

internal sealed record ProcessCall(string FileName, string[] Arguments);
