using System.ComponentModel;
using System.Runtime.CompilerServices;
using PocketDarwin.Launcher.Services;

namespace PocketDarwin.Launcher.ViewModels;

public sealed class MainViewModel(Func<CancellationToken, Task<HostInfo>> inspectHost) : INotifyPropertyChanged
{
    private bool _isBusy;
    private string _statusMessage = "Проверка ещё не запускалась";
    private string _cpuStatus = "—";
    private string _distroStatus = "—";
    private string _wslgStatus = "—";
    private string _errors = "Нет";

    public event PropertyChangedEventHandler? PropertyChanged;
    public bool IsBusy { get => _isBusy; private set => Set(ref _isBusy, value); }
    public string StatusMessage { get => _statusMessage; private set => Set(ref _statusMessage, value); }
    public string CpuStatus { get => _cpuStatus; private set => Set(ref _cpuStatus, value); }
    public string DistroStatus { get => _distroStatus; private set => Set(ref _distroStatus, value); }
    public string WslgStatus { get => _wslgStatus; private set => Set(ref _wslgStatus, value); }
    public string Errors { get => _errors; private set => Set(ref _errors, value); }

    public async Task RefreshAsync(CancellationToken cancellationToken = default)
    {
        IsBusy = true;
        StatusMessage = "Проверяю Windows, WSL2 и графический вывод…";
        try
        {
            var host = await inspectHost(cancellationToken);
            CpuStatus = $"{host.CpuName} · {host.RamBytes / (1024 * 1024 * 1024)} GiB · {host.Architecture}";
            DistroStatus = host.DistroName is null ? "Не найден" : $"{host.DistroName} · WSL {host.WslVersion} · {host.DistroState}";
            WslgStatus = host.WslgAvailable ? "Доступен" : "Недоступен";
            Errors = host.Errors.Count == 0 ? "Нет" : string.Join(", ", host.Errors);
            StatusMessage = host.Errors.Count == 0
                ? "WSL готов; iOS-прошивка и запуск ещё не проверены"
                : FormatError(host.Errors[0]);
        }
        catch (OperationCanceledException)
        {
            StatusMessage = "Проверка отменена";
        }
        catch (Exception exception)
        {
            Errors = "HOST_CHECK_FAILED";
            StatusMessage = $"Проверка не удалась: {exception.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    private static string FormatError(string error) => error switch
    {
        "WSL_NOT_INSTALLED" => "WSL не установлен (WSL_NOT_INSTALLED)",
        "WSL_DISTRO_NOT_FOUND" => "Дистрибутив Ubuntu не найден (WSL_DISTRO_NOT_FOUND)",
        "WSL2_REQUIRED" => "Нужен WSL 2 (WSL2_REQUIRED)",
        "WSL_DISTRO_STOPPED" => "Запусти Ubuntu один раз из меню Пуск (WSL_DISTRO_STOPPED)",
        "WSLG_UNAVAILABLE" => "В WSL нет графического канала WSLg (WSLG_UNAVAILABLE)",
        _ => $"Проверка окружения: {error}"
    };

    private void Set<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
