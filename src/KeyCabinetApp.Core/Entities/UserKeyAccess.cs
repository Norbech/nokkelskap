namespace KeyCabinetApp.Core.Entities;

public class UserKeyAccess
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int KeyId { get; set; }
    public DateTime GrantedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public User User { get; set; } = null!;
    public Key Key { get; set; } = null!;
}
