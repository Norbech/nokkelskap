using KeyCabinetApp.Application.Services;
using Microsoft.Extensions.Logging;
using System.Windows.Input;

namespace KeyCabinetApp.UI.ViewModels;

public class MainViewModel : ViewModelBase
{
    private readonly AuthenticationService _authService;
    private readonly ILogger<MainViewModel> _logger;
    private readonly IServiceProvider _serviceProvider;
    
    private ViewModelBase? _currentViewModel;
    private bool _isLoggedIn;

    public MainViewModel(
        AuthenticationService authService,
        ILogger<MainViewModel> logger,
        IServiceProvider serviceProvider)
    {
        _authService = authService;
        _logger = logger;
        _serviceProvider = serviceProvider;

        ShowLoginCommand = new RelayCommand(_ => ShowLogin());
        ShowAdminCommand = new RelayCommand(_ => ShowAdmin(), _ => IsAdmin());
        ShowLogViewerCommand = new RelayCommand(_ => ShowLogViewer(), _ => IsAdmin());

        // Subscribe to auth events
        _authService.UserLoggedIn += OnUserLoggedIn;
        _authService.UserLoggedOut += OnUserLoggedOut;

        // Show login initially
        ShowLogin();
    }

    public ViewModelBase? CurrentViewModel
    {
        get => _currentViewModel;
        set => SetProperty(ref _currentViewModel, value);
    }

    public bool IsLoggedIn
    {
        get => _isLoggedIn;
        set => SetProperty(ref _isLoggedIn, value);
    }

    public ICommand ShowLoginCommand { get; }
    public ICommand ShowAdminCommand { get; }
    public ICommand ShowLogViewerCommand { get; }

    private void ShowLogin()
    {
        var loginVm = (LoginViewModel)_serviceProvider.GetService(typeof(LoginViewModel))!;
        loginVm.LoginCompleted += (s, success) =>
        {
            if (success)
            {
                ShowKeySelection();
            }
        };
        CurrentViewModel = loginVm;
        IsLoggedIn = false;
    }

    private async void ShowKeySelection()
    {
        var keySelectionVm = (KeySelectionViewModel)_serviceProvider.GetService(typeof(KeySelectionViewModel))!;
        keySelectionVm.LogoutRequested += (s, e) => ShowLogin();
        
        CurrentViewModel = keySelectionVm;
        IsLoggedIn = true;

        await keySelectionVm.LoadUserKeysAsync();
    }

    private void ShowAdmin()
    {
        var adminVm = (AdminViewModel)_serviceProvider.GetService(typeof(AdminViewModel))!;
        adminVm.CloseRequested += (s, e) => ShowKeySelection();
        CurrentViewModel = adminVm;
    }

    private void ShowLogViewer()
    {
        var logViewerVm = (LogViewerViewModel)_serviceProvider.GetService(typeof(LogViewerViewModel))!;
        logViewerVm.CloseRequested += (s, e) => ShowKeySelection();
        CurrentViewModel = logViewerVm;
        
        _ = logViewerVm.LoadEventsAsync();
    }

    private void OnUserLoggedIn(object? sender, Core.Entities.User user)
    {
        _logger.LogInformation("User logged in: {UserName}", user.Name);
        IsLoggedIn = true;
    }

    private void OnUserLoggedOut(object? sender, EventArgs e)
    {
        _logger.LogInformation("User logged out");
        IsLoggedIn = false;
        ShowLogin();
    }

    private bool IsAdmin()
    {
        return _authService.CurrentUser?.IsAdmin ?? false;
    }
}
