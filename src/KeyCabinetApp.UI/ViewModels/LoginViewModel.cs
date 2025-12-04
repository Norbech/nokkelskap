using KeyCabinetApp.Application.Services;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;
using System.Windows.Input;

namespace KeyCabinetApp.UI.ViewModels;

public class LoginViewModel : ViewModelBase
{
    private readonly AuthenticationService _authService;
    private readonly IRfidReader _rfidReader;
    private readonly ILogger<LoginViewModel> _logger;
    
    private string _username = string.Empty;
    private string _password = string.Empty;
    private string _statusMessage = "Skann RFID-kort eller logg inn med brukernavn";
    private bool _isError;
    private bool _showPasswordLogin;

    public LoginViewModel(
        AuthenticationService authService,
        IRfidReader rfidReader,
        ILogger<LoginViewModel> logger)
    {
        _authService = authService;
        _rfidReader = rfidReader;
        _logger = logger;

        LoginCommand = new AsyncRelayCommand(async _ => await LoginAsync(), _ => CanLogin());
        ShowPasswordLoginCommand = new RelayCommand(_ => ShowPasswordLogin = true);
        CancelPasswordLoginCommand = new RelayCommand(_ => 
        {
            ShowPasswordLogin = false;
            Username = string.Empty;
            Password = string.Empty;
        });

        // Subscribe to RFID scans
        _rfidReader.CardScanned += OnRfidCardScanned;
        _rfidReader.StartListening();
    }

    public string Username
    {
        get => _username;
        set => SetProperty(ref _username, value);
    }

    public string Password
    {
        get => _password;
        set => SetProperty(ref _password, value);
    }

    public string StatusMessage
    {
        get => _statusMessage;
        set => SetProperty(ref _statusMessage, value);
    }

    public bool IsError
    {
        get => _isError;
        set => SetProperty(ref _isError, value);
    }

    public bool ShowPasswordLogin
    {
        get => _showPasswordLogin;
        set => SetProperty(ref _showPasswordLogin, value);
    }

    public ICommand LoginCommand { get; }
    public ICommand ShowPasswordLoginCommand { get; }
    public ICommand CancelPasswordLoginCommand { get; }

    public event EventHandler<bool>? LoginCompleted;

    private async void OnRfidCardScanned(object? sender, string rfidTag)
    {
        _logger.LogInformation("RFID card scanned in login view");
        
        var (success, user, message) = await _authService.AuthenticateByRfidAsync(rfidTag);

        if (success)
        {
            StatusMessage = $"Velkommen, {user?.Name}!";
            IsError = false;
            
            // Notify success
            await Task.Delay(500); // Brief delay to show welcome message
            LoginCompleted?.Invoke(this, true);
        }
        else
        {
            StatusMessage = message;
            IsError = true;
            
            // Reset after delay
            await Task.Delay(3000);
            StatusMessage = "Skann RFID-kort eller logg inn med brukernavn";
            IsError = false;
        }
    }

    private bool CanLogin()
    {
        return !string.IsNullOrWhiteSpace(Username) && !string.IsNullOrWhiteSpace(Password);
    }

    private async Task LoginAsync()
    {
        StatusMessage = "Logger inn...";
        IsError = false;

        var (success, user, message) = await _authService.AuthenticateByPasswordAsync(Username, Password);

        if (success)
        {
            StatusMessage = $"Velkommen, {user?.Name}!";
            IsError = false;
            Password = string.Empty;
            
            await Task.Delay(500);
            LoginCompleted?.Invoke(this, true);
        }
        else
        {
            StatusMessage = message;
            IsError = true;
            Password = string.Empty;
        }
    }

    public void Cleanup()
    {
        _rfidReader.CardScanned -= OnRfidCardScanned;
    }
}
