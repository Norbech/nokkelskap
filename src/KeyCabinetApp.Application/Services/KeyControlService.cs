using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace KeyCabinetApp.Application.Services;

public class KeyControlService
{
    private readonly IKeyRepository _keyRepository;
    private readonly ISerialCommunication _serialCommunication;
    private readonly IEventRepository _eventRepository;
    private readonly ILogger<KeyControlService> _logger;

    public KeyControlService(
        IKeyRepository keyRepository,
        ISerialCommunication serialCommunication,
        IEventRepository eventRepository,
        ILogger<KeyControlService> logger)
    {
        _keyRepository = keyRepository;
        _serialCommunication = serialCommunication;
        _eventRepository = eventRepository;
        _logger = logger;
    }

    public event EventHandler<(Key Key, bool Success)>? KeyOpened;

    /// <summary>
    /// Opens a specific key slot
    /// </summary>
    public async Task<(bool Success, string Message)> OpenKeyAsync(int keyId, int userId, string authMethod)
    {
        try
        {
            var key = await _keyRepository.GetByIdAsync(keyId);
            if (key == null)
            {
                _logger.LogWarning("Attempted to open non-existent key ID: {KeyId}", keyId);
                return (false, "Nøkkel ikke funnet");
            }

            if (!key.IsActive)
            {
                _logger.LogWarning("Attempted to open inactive key: {KeyName}", key.Name);
                return (false, "Nøkkel er deaktivert");
            }

            // Ensure serial connection
            if (!_serialCommunication.IsConnected)
            {
                var connected = await _serialCommunication.ConnectAsync();
                if (!connected)
                {
                    await LogKeyEventAsync(userId, keyId, key.SlotId, authMethod, false, "Serial connection failed");
                    return (false, "Kunne ikke koble til nøkkelskap");
                }
            }

            // Send command to open the slot
            var success = await _serialCommunication.OpenSlotAsync(key.SlotId);

            if (success)
            {
                await LogKeyEventAsync(userId, keyId, key.SlotId, authMethod, true, $"Opened {key.Name}");
                _logger.LogInformation("Successfully opened key {KeyName} (slot {SlotId}) for user {UserId}", 
                    key.Name, key.SlotId, userId);
                
                KeyOpened?.Invoke(this, (key, true));
                return (true, $"{key.Name} åpnet");
            }
            else
            {
                await LogKeyEventAsync(userId, keyId, key.SlotId, authMethod, false, "Command failed");
                _logger.LogError("Failed to open key {KeyName} (slot {SlotId})", key.Name, key.SlotId);
                
                KeyOpened?.Invoke(this, (key, false));
                return (false, "Kunne ikke åpne nøkkel");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error opening key ID: {KeyId}", keyId);
            await LogKeyEventAsync(userId, keyId, null, authMethod, false, $"Exception: {ex.Message}");
            return (false, "En feil oppstod");
        }
    }

    /// <summary>
    /// Opens a key by slot ID (for remote opening)
    /// </summary>
    public async Task<(bool Success, string Message)> OpenKeyBySlotIdAsync(int slotId, int userId, string authMethod = "REMOTE")
    {
        try
        {
            var key = await _keyRepository.GetBySlotIdAsync(slotId);
            if (key == null)
            {
                _logger.LogWarning("Attempted to open non-existent slot ID: {SlotId}", slotId);
                return (false, "Slot ikke funnet");
            }

            return await OpenKeyAsync(key.Id, userId, authMethod);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error opening slot ID: {SlotId}", slotId);
            return (false, "En feil oppstod");
        }
    }

    /// <summary>
    /// Gets all keys accessible to a specific user
    /// </summary>
    public async Task<IEnumerable<Key>> GetUserKeysAsync(int userId)
    {
        return await _keyRepository.GetKeysForUserAsync(userId);
    }

    /// <summary>
    /// Checks if user has access to a specific key
    /// </summary>
    public async Task<bool> UserHasAccessToKeyAsync(int userId, int keyId)
    {
        var userKeys = await _keyRepository.GetKeysForUserAsync(userId);
        return userKeys.Any(k => k.Id == keyId);
    }

    /// <summary>
    /// Gets status for a key slot (if supported by hardware)
    /// </summary>
    public async Task<string?> GetKeyStatusAsync(int keyId)
    {
        try
        {
            var key = await _keyRepository.GetByIdAsync(keyId);
            if (key == null)
                return null;

            if (!_serialCommunication.IsConnected)
                await _serialCommunication.ConnectAsync();

            return await _serialCommunication.GetSlotStatusAsync(key.SlotId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting status for key ID: {KeyId}", keyId);
            return null;
        }
    }
    
    /// <summary>
    /// Gets status for a slot by slot ID
    /// </summary>
    public async Task<string?> GetSlotStatusAsync(int slotId)
    {
        try
        {
            if (!_serialCommunication.IsConnected)
                await _serialCommunication.ConnectAsync();

            return await _serialCommunication.GetSlotStatusAsync(slotId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting status for slot ID: {SlotId}", slotId);
            return null;
        }
    }

    private async Task LogKeyEventAsync(int userId, int? keyId, int? slotId, string authMethod, bool success, string details)
    {
        await _eventRepository.AddAsync(new Event
        {
            UserId = userId,
            KeyId = keyId,
            SlotId = slotId,
            ActionType = authMethod == "REMOTE" ? Core.Enums.ActionTypes.REMOTE_OPEN : Core.Enums.ActionTypes.OPEN,
            AuthMethod = authMethod,
            Details = details,
            Success = success,
            Timestamp = DateTime.UtcNow
        });
    }
}
