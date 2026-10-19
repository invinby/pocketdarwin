using PocketDarwin.Launcher.ViewModels;
using Xunit;

namespace PocketDarwin.Launcher.Tests;

public sealed class MainViewModelTests
{
    [Fact]
    public async Task Refresh_shows_host_name_and_stops_loading()
    {
        var model = new MainViewModel(_ => Task.FromResult(new Services.HostInfo("26200", "X64", "AMD Ryzen", 16L << 30, true, 2, "Ubuntu", "Running", true, 100L << 30, [])));

        await model.RefreshAsync();

        Assert.Equal("Ubuntu · WSL 2 · Running", model.DistroStatus);
        Assert.Equal("WSL готов; iOS-прошивка и запуск ещё не проверены", model.StatusMessage);
        Assert.False(model.IsBusy);
    }

    [Fact]
    public async Task Refresh_surfaces_actionable_wsl_error()
    {
        var model = new MainViewModel(_ => Task.FromResult(new Services.HostInfo("26200", "X64", "AMD Ryzen", 16L << 30, false, null, null, null, false, null, ["WSL_NOT_INSTALLED"])));

        await model.RefreshAsync();

        Assert.Equal("WSL не установлен (WSL_NOT_INSTALLED)", model.StatusMessage);
    }
}
