using KeyCabinetApp.Application.Services;
using KeyCabinetApp.Core.Entities;
using Microsoft.Extensions.Logging;
using System.Collections.ObjectModel;
using System.Windows.Input;
using KeyEntity = KeyCabinetApp.Core.Entities.Key;

namespace KeyCabinetApp.UI.ViewModels;

public class KeySelectionViewModel : ViewModelBase
{
    private readonly AuthenticationService _authService;
    private readonly KeyControlService _keyControlService;
    private readonly ILogger<KeySelectionViewModel> _logger;
    
    private string _userName = string.Empty;
    private string _statusMessage = string.Empty;
    private bool _isError;
    private KeyEntity? _selectedKey;

    public KeySelectionViewModel(
        AuthenticationService authService,
        KeyControlService keyControlService,
        ILogger<KeySelectionViewModel> logger)
    {
        _authService = authService;
        _keyControlService = keyControlService;
        _logger = logger;

        AvailableKeys = new ObservableCollection<KeyEntity>();
        
        OpenKeyCommand = new AsyncRelayCommand(async _ => await OpenSelectedKeyAsync(), _ => SelectedKey != null);
        LogoutCommand = new RelayCommand(_ => Logout());

        _keyControlService.KeyOpened += OnKeyOpened;
    }

    public ObservableCollection<KeyEntity> AvailableKeys { get; }

    public string UserName
    {
        get => _userName;
        set => SetProperty(ref _userName, value);
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

    public KeyEntity? SelectedKey
    {
        get => _selectedKey;
        set => SetProperty(ref _selectedKey, value);
    }

    public ICommand OpenKeyCommand { get; }
    public ICommand LogoutCommand { get; }

    public event EventHandler? LogoutRequested;

    public async Task LoadUserKeysAsync()
    {
        var currentUser = _authService.CurrentUser;
        if (currentUser == null)
        {
            _logger.LogWarning("No current user when loading keys");
            return;
        }

        UserName = currentUser.Name;
        StatusMessage = "Velg nøkkel å åpne";
        IsError = false;

        var keys = await _keyControlService.GetUserKeysAsync(currentUser.Id);
        
        AvailableKeys.Clear();
        foreach (var key in keys.OrderBy(k => k.Name))
        {
            AvailableKeys.Add(key);
        }

        _logger.LogInformation("Loaded {KeyCount} keys for user {UserName}", AvailableKeys.Count, UserName);
    }

    private async Task OpenSelectedKeyAsync()
    {
        if (SelectedKey == null || _authService.CurrentUser == null)
            return;

        StatusMessage = $"Åpner {SelectedKey.Name}...";
        IsError = false;

        var (success, message) = await _keyControlService.OpenKeyAsync(
            SelectedKey.Id,
            _authService.CurrentUser.Id,
            _authService.CurrentUser.RfidTag != null ? "RFID" : "PASSWORD");

        StatusMessage = message;
        IsError = !success;

        if (success)
        {
            // Reset status after delay
            await Task.Delay(2000);
            StatusMessage = "Velg nøkkel å åpne";
            IsError = false;
        }
    }

    private void OnKeyOpened(object? sender, (KeyEntity Key, bool Success) e)
    {
        // UI feedback already handled in OpenSelectedKeyAsync
    }

    private void Logout()
    {
        _authService.Logout();
        LogoutRequested?.Invoke(this, EventArgs.Empty);
    }

    public void Cleanup()
    {
        _keyControlService.KeyOpened -= OnKeyOpened;
    }
}
