using KeyCabinetApp.Core.Entities;
using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;

namespace KeyCabinetApp.Web.Services;

/// <summary>
/// Manages session state for the current Blazor circuit with persistent storage
/// </summary>
public class SessionStateService
{
    private readonly ProtectedSessionStorage _sessionStorage;
    private const string UserStorageKey = "CurrentUser";
    private User? _currentUser;
    private bool _isInitialized;

    public SessionStateService(ProtectedSessionStorage sessionStorage)
    {
        _sessionStorage = sessionStorage;
    }

    public User? CurrentUser => _currentUser;

    public event EventHandler<User?>? CurrentUserChanged;

    public async Task InitializeAsync()
    {
        if (_isInitialized) return;

        try
        {
            var result = await _sessionStorage.GetAsync<User>(UserStorageKey);
            if (result.Success)
            {
                _currentUser = result.Value;
            }
        }
        catch
        {
            // Session storage not available yet or error reading
            _currentUser = null;
        }

        _isInitialized = true;
    }

    public async Task SetCurrentUserAsync(User? user)
    {
        _currentUser = user;
        
        if (user != null)
        {
            await _sessionStorage.SetAsync(UserStorageKey, user);
        }
        else
        {
            await _sessionStorage.DeleteAsync(UserStorageKey);
        }

        CurrentUserChanged?.Invoke(this, user);
    }

    public async Task ClearAsync()
    {
        _currentUser = null;
        await _sessionStorage.DeleteAsync(UserStorageKey);
        CurrentUserChanged?.Invoke(this, null);
    }

    // Sync methods for backward compatibility
    public void SetCurrentUser(User? user)
    {
        _ = SetCurrentUserAsync(user);
    }

    public void Clear()
    {
        _ = ClearAsync();
    }

    public bool IsAuthenticated => _currentUser != null;
    public bool IsAdmin => _currentUser?.IsAdmin ?? false;
}
