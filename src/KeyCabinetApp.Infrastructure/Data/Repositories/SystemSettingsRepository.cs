using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace KeyCabinetApp.Infrastructure.Data.Repositories;

public class SystemSettingsRepository : ISystemSettingsRepository
{
    private readonly ApplicationDbContext _context;

    public SystemSettingsRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<SystemSettings> GetSettingsAsync()
    {
        var settings = await _context.SystemSettings.FirstOrDefaultAsync();
        
        if (settings == null)
        {
            // Create default settings if none exist
            settings = new SystemSettings
            {
                CooldownSeconds = 5,
                StatusRefreshIntervalSeconds = 5,
                StatusInitialDelaySeconds = 2,
                EnableDoorStatus = true,
                EnableCooldown = true,
                SessionTimeoutMinutes = 30,
                LastModified = DateTime.UtcNow
            };
            
            _context.SystemSettings.Add(settings);
            await _context.SaveChangesAsync();
        }
        
        return settings;
    }

    public async Task<SystemSettings> UpdateSettingsAsync(SystemSettings settings)
    {
        settings.LastModified = DateTime.UtcNow;
        _context.SystemSettings.Update(settings);
        await _context.SaveChangesAsync();
        return settings;
    }
}
