using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;
using BCrypt.Net;

namespace KeyCabinetApp.Application.Services;

public class AuthenticationService
{
    private readonly IUserRepository _userRepository;
    private readonly IEventRepository _eventRepository;
    private readonly ILogger<AuthenticationService> _logger;
    private User? _currentUser;

    public AuthenticationService(
        IUserRepository userRepository,
        IEventRepository eventRepository,
        ILogger<AuthenticationService> logger)
    {
        _userRepository = userRepository;
        _eventRepository = eventRepository;
        _logger = logger;
    }

    public User? CurrentUser => _currentUser;

    public event EventHandler<User>? UserLoggedIn;
    public event EventHandler? UserLoggedOut;

    /// <summary>
    /// Authenticates a user by RFID tag
    /// </summary>
    public async Task<(bool Success, User? User, string Message)> AuthenticateByRfidAsync(string rfidTag)
    {
        try
        {
            _logger.LogInformation("Attempting RFID authentication for tag: {RfidTag}", MaskRfid(rfidTag));

            var user = await _userRepository.GetByRfidAsync(rfidTag);

            if (user == null)
            {
                await LogFailedLoginAsync(null, Core.Enums.AuthMethods.RFID, $"Unknown RFID: {MaskRfid(rfidTag)}");
                return (false, null, "RFID-kortet er ikke registrert");
            }

            if (!user.IsActive)
            {
                await LogFailedLoginAsync(user.Id, Core.Enums.AuthMethods.RFID, "User is inactive");
                return (false, null, "Brukerkontoen er deaktivert");
            }

            await LoginUserAsync(user, Core.Enums.AuthMethods.RFID);
            return (true, user, "Innlogget");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during RFID authentication");
            return (false, null, "En feil oppstod under innlogging");
        }
    }

    /// <summary>
    /// Authenticates a user by username and password
    /// </summary>
    public async Task<(bool Success, User? User, string Message)> AuthenticateByPasswordAsync(string username, string password)
    {
        try
        {
            _logger.LogInformation("Attempting password authentication for user: {Username}", username);

            var user = await _userRepository.GetByUsernameAsync(username);

            if (user == null)
            {
                await LogFailedLoginAsync(null, Core.Enums.AuthMethods.PASSWORD, $"Unknown username: {username}");
                return (false, null, "Ugyldig brukernavn eller passord");
            }

            if (!user.IsActive)
            {
                await LogFailedLoginAsync(user.Id, Core.Enums.AuthMethods.PASSWORD, "User is inactive");
                return (false, null, "Brukerkontoen er deaktivert");
            }

            // Verify password using BCrypt
            bool passwordValid = BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);

            if (!passwordValid)
            {
                await LogFailedLoginAsync(user.Id, Core.Enums.AuthMethods.PASSWORD, "Invalid password");
                return (false, null, "Ugyldig brukernavn eller passord");
            }

            await LoginUserAsync(user, Core.Enums.AuthMethods.PASSWORD);
            return (true, user, "Innlogget");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during password authentication");
            return (false, null, "En feil oppstod under innlogging");
        }
    }

    /// <summary>
    /// Authenticates for remote API access
    /// </summary>
    public async Task<(bool Success, User? User)> AuthenticateForRemoteAccessAsync(string username, string password)
    {
        var user = await _userRepository.GetByUsernameAsync(username);
        
        if (user == null || !user.IsActive)
            return (false, null);

        bool passwordValid = BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
        return (passwordValid, passwordValid ? user : null);
    }

    /// <summary>
    /// Logs out the current user
    /// </summary>
    public void Logout()
    {
        if (_currentUser != null)
        {
            _logger.LogInformation("User {Username} logged out", _currentUser.Username);
            _currentUser = null;
            UserLoggedOut?.Invoke(this, EventArgs.Empty);
        }
    }

    /// <summary>
    /// Creates a new user with hashed password
    /// </summary>
    public async Task<User> CreateUserAsync(string name, string username, string password, string? rfidTag = null, bool isAdmin = false)
    {
        var salt = BCrypt.Net.BCrypt.GenerateSalt(12);
        var hash = BCrypt.Net.BCrypt.HashPassword(password, salt);

        var user = new User
        {
            Name = name,
            Username = username,
            PasswordHash = hash,
            PasswordSalt = salt,
            RfidTag = rfidTag,
            IsAdmin = isAdmin,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        var createdUser = await _userRepository.AddAsync(user);
        
        await _eventRepository.AddAsync(new Event
        {
            UserId = _currentUser?.Id,
            ActionType = Core.Enums.ActionTypes.USER_CREATED,
            AuthMethod = Core.Enums.AuthMethods.NONE,
            Details = $"Created user: {username}",
            Timestamp = DateTime.UtcNow
        });

        _logger.LogInformation("Created new user: {Username}", username);
        return createdUser;
    }

    /// <summary>
    /// Updates user password
    /// </summary>
    public async Task UpdatePasswordAsync(int userId, string newPassword)
    {
        var user = await _userRepository.GetByIdAsync(userId);
        if (user == null)
            throw new ArgumentException("User not found");

        var salt = BCrypt.Net.BCrypt.GenerateSalt(12);
        var hash = BCrypt.Net.BCrypt.HashPassword(newPassword, salt);

        user.PasswordHash = hash;
        user.PasswordSalt = salt;

        await _userRepository.UpdateAsync(user);
        
        await _eventRepository.AddAsync(new Event
        {
            UserId = _currentUser?.Id,
            ActionType = Core.Enums.ActionTypes.USER_MODIFIED,
            AuthMethod = Core.Enums.AuthMethods.NONE,
            Details = $"Password changed for user ID: {userId}",
            Timestamp = DateTime.UtcNow
        });

        _logger.LogInformation("Password updated for user ID: {UserId}", userId);
    }

    private async Task LoginUserAsync(User user, string authMethod)
    {
        _currentUser = user;
        user.LastLoginAt = DateTime.UtcNow;
        await _userRepository.UpdateAsync(user);

        await _eventRepository.AddAsync(new Event
        {
            UserId = user.Id,
            ActionType = Core.Enums.ActionTypes.SUCCESSFUL_LOGIN,
            AuthMethod = authMethod,
            Details = $"User {user.Username} logged in via {authMethod}",
            Timestamp = DateTime.UtcNow,
            Success = true
        });

        _logger.LogInformation("User {Username} logged in successfully via {AuthMethod}", user.Username, authMethod);
        UserLoggedIn?.Invoke(this, user);
    }

    private async Task LogFailedLoginAsync(int? userId, string authMethod, string details)
    {
        await _eventRepository.AddAsync(new Event
        {
            UserId = userId,
            ActionType = Core.Enums.ActionTypes.FAILED_LOGIN,
            AuthMethod = authMethod,
            Details = details,
            Timestamp = DateTime.UtcNow,
            Success = false
        });

        _logger.LogWarning("Failed login attempt: {Details}", details);
    }

    private string MaskRfid(string rfid)
    {
        if (rfid.Length <= 4)
            return "****";
        return rfid.Substring(0, 4) + new string('*', rfid.Length - 4);
    }
}
