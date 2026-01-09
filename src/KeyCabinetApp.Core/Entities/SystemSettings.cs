namespace KeyCabinetApp.Core.Entities;

/// <summary>
/// System settings for the key cabinet application
/// </summary>
public class SystemSettings
{
    public int Id { get; set; }
    
    /// <summary>
    /// Cooldown time in seconds between opening the same key
    /// </summary>
    public int CooldownSeconds { get; set; } = 5;
    
    /// <summary>
    /// Interval in seconds for refreshing door status
    /// </summary>
    public int StatusRefreshIntervalSeconds { get; set; } = 5;
    
    /// <summary>
    /// Initial delay in seconds before first status refresh
    /// </summary>
    public int StatusInitialDelaySeconds { get; set; } = 2;
    
    /// <summary>
    /// Enable door status indicators
    /// </summary>
    public bool EnableDoorStatus { get; set; } = true;
    
    /// <summary>
    /// Enable cooldown protection
    /// </summary>
    public bool EnableCooldown { get; set; } = true;
    
    /// <summary>
    /// Session timeout in minutes
    /// </summary>
    public int SessionTimeoutMinutes { get; set; } = 30;
    
    /// <summary>
    /// Last modified timestamp
    /// </summary>
    public DateTime LastModified { get; set; } = DateTime.UtcNow;
}
