using System.Windows;
using PocketDarwin.Launcher.Services;
using PocketDarwin.Launcher.ViewModels;

namespace PocketDarwin.Launcher;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel = new(token => new HostStatusService(new ProcessRunner()).GetHostInfoAsync(token));

    public MainWindow()
    {
        InitializeComponent();
        DataContext = _viewModel;
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e) => await _viewModel.RefreshAsync();

    private async void Refresh_Click(object sender, RoutedEventArgs e) => await _viewModel.RefreshAsync();
}
