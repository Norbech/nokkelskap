using KeyCabinetApp.Application.Services;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;
using System.Windows.Input;
using System.Windows.Threading;

namespace KeyCabinetApp.UI.ViewModels;

public class MainViewModel : ViewModelBase
{
    private readonly AuthenticationService _authService;
    private readonly ILogger<MainViewModel> _logger;
    private readonly IServiceProvider _serviceProvider;
    private readonly ISerialCommunication _serialCommunication;
    private readonly DispatcherTimer _connectionCheckTimer;
    
    private ViewModelBase? _currentViewModel;
    private bool _isLoggedIn;
    private bool _isSerialConnected;

    public MainViewModel(
        AuthenticationService authService,
        ILogger<MainViewModel> logger,
        IServiceProvider serviceProvider,
        ISerialCommunication serialCommunication)
    {
        _authService = authService;
        _logger = logger;
        _serviceProvider = serviceProvider;
        _serialCommunication = serialCommunication;

        ShowLoginCommand = new RelayCommand(_ => ShowLogin());
        ShowAdminCommand = new RelayCommand(_ => ShowAdmin(), _ => IsAdmin());
        ShowLogViewerCommand = new RelayCommand(_ => ShowLogViewer(), _ => IsAdmin());

        // Subscribe to auth events
        _authService.UserLoggedIn += OnUserLoggedIn;
        _authService.UserLoggedOut += OnUserLoggedOut;

        // Setup connection check timer
        _connectionCheckTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(2)
        };
        _connectionCheckTimer.Tick += async (s, e) => await CheckSerialConnectionAsync();
        _connectionCheckTimer.Start();

        // Initial connection attempt
        _ = InitializeSerialConnectionAsync();

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

    public bool IsSerialConnected
    {
        get => _isSerialConnected;
        set => SetProperty(ref _isSerialConnected, value);
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

    private async Task InitializeSerialConnectionAsync()
    {
        try
        {
            _logger.LogInformation("Attempting to connect to serial port...");
            var connected = await _serialCommunication.ConnectAsync();
            IsSerialConnected = connected;
            
            if (connected)
            {
                _logger.LogInformation("Serial port connected successfully");
            }
            else
            {
                _logger.LogWarning("Failed to connect to serial port");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error connecting to serial port");
            IsSerialConnected = false;
        }
    }

    private async Task CheckSerialConnectionAsync()
    {
        try
        {
            var wasConnected = IsSerialConnected;
            IsSerialConnected = _serialCommunication.IsConnected;
            
            // Try to reconnect if disconnected
            if (!IsSerialConnected && !wasConnected)
            {
                await _serialCommunication.ConnectAsync();
                IsSerialConnected = _serialCommunication.IsConnected;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking serial connection");
            IsSerialConnected = false;
        }
    }
}
