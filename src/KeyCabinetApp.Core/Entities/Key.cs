namespace KeyCabinetApp.Core.Entities;

public class Key
{
    public int Id { get; set; }
    public int SlotId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public ICollection<UserKeyAccess> UserAccess { get; set; } = new List<UserKeyAccess>();
    public ICollection<Event> Events { get; set; } = new List<Event>();
}
