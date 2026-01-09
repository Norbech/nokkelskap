using KeyCabinetApp.Core.Entities;

namespace KeyCabinetApp.Core.Interfaces;

public interface ISystemSettingsRepository
{
    Task<SystemSettings> GetSettingsAsync();
    Task<SystemSettings> UpdateSettingsAsync(SystemSettings settings);
}
