using KeyCabinetApp.Core.Entities;

namespace KeyCabinetApp.Web.Services;

/// <summary>
/// Manages session state for the current Blazor circuit
/// </summary>
public class SessionStateService
{
    private User? _currentUser;

    public User? CurrentUser => _currentUser;

    public event EventHandler<User?>? CurrentUserChanged;

    public void SetCurrentUser(User? user)
    {
        _currentUser = user;
        CurrentUserChanged?.Invoke(this, user);
    }

    public void Clear()
    {
        _currentUser = null;
        CurrentUserChanged?.Invoke(this, null);
    }

    public bool IsAuthenticated => _currentUser != null;
    public bool IsAdmin => _currentUser?.IsAdmin ?? false;
}
