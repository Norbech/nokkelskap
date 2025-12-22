using System.Text.Json.Serialization;

namespace KeyCabinetApp.Core.Entities;

public class Event
{
    public int Id { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public int? UserId { get; set; }
    public int? KeyId { get; set; }
    public int? SlotId { get; set; }
    public string ActionType { get; set; } = string.Empty;
    public string AuthMethod { get; set; } = string.Empty;
    public string? Details { get; set; }
    public bool Success { get; set; } = true;

    // Navigation properties
    [JsonIgnore]
    public User? User { get; set; }
    [JsonIgnore]
    public Key? Key { get; set; }
}
