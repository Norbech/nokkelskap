using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace KeyCabinetApp.Application.Services;

public class SystemSettingsService
{
    private readonly ISystemSettingsRepository _settingsRepository;
    private readonly ILogger<SystemSettingsService> _logger;
    private SystemSettings? _cachedSettings;
    private DateTime _lastCacheTime = DateTime.MinValue;
    private readonly TimeSpan _cacheExpiration = TimeSpan.FromMinutes(5);

    public SystemSettingsService(
        ISystemSettingsRepository settingsRepository,
        ILogger<SystemSettingsService> logger)
    {
        _settingsRepository = settingsRepository;
        _logger = logger;
    }

    public async Task<SystemSettings> GetSettingsAsync()
    {
        try
        {
            // Return cached settings if still valid
            if (_cachedSettings != null && DateTime.UtcNow - _lastCacheTime < _cacheExpiration)
            {
                return _cachedSettings;
            }

            _cachedSettings = await _settingsRepository.GetSettingsAsync();
            _lastCacheTime = DateTime.UtcNow;
            return _cachedSettings;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting system settings");
            
            // Return default settings on error
            return new SystemSettings
            {
                CooldownSeconds = 5,
                StatusRefreshIntervalSeconds = 5,
                StatusInitialDelaySeconds = 2,
                EnableDoorStatus = true,
                EnableCooldown = true,
                SessionTimeoutMinutes = 30
            };
        }
    }

    public async Task<SystemSettings> UpdateSettingsAsync(SystemSettings settings)
    {
        try
        {
            var updated = await _settingsRepository.UpdateSettingsAsync(settings);
            
            // Invalidate cache
            _cachedSettings = updated;
            _lastCacheTime = DateTime.UtcNow;
            
            _logger.LogInformation("System settings updated");
            return updated;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating system settings");
            throw;
        }
    }

    public void InvalidateCache()
    {
        _cachedSettings = null;
        _lastCacheTime = DateTime.MinValue;
    }
}
