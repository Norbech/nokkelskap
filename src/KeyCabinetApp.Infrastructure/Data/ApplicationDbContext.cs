using KeyCabinetApp.Core.Entities;
using Microsoft.EntityFrameworkCore;

namespace KeyCabinetApp.Infrastructure.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Key> Keys { get; set; }
    public DbSet<UserKeyAccess> UserKeyAccess { get; set; }
    public DbSet<Event> Events { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User entity configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Username).IsRequired().HasMaxLength(100);
            entity.HasIndex(e => e.Username).IsUnique();
            entity.Property(e => e.RfidTag).HasMaxLength(100);
            entity.HasIndex(e => e.RfidTag).IsUnique();
            entity.Property(e => e.PasswordHash).IsRequired().HasMaxLength(500);
            entity.Property(e => e.PasswordSalt).IsRequired().HasMaxLength(500);
        });

        // Key entity configuration
        modelBuilder.Entity<Key>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.HasIndex(e => e.SlotId).IsUnique();
        });

        // UserKeyAccess entity configuration
        modelBuilder.Entity<UserKeyAccess>(entity =>
        {
            entity.HasKey(e => e.Id);
            
            entity.HasOne(e => e.User)
                .WithMany(u => u.KeyAccess)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Key)
                .WithMany(k => k.UserAccess)
                .HasForeignKey(e => e.KeyId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.UserId, e.KeyId }).IsUnique();
        });

        // Event entity configuration
        modelBuilder.Entity<Event>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.ActionType).IsRequired().HasMaxLength(50);
            entity.Property(e => e.AuthMethod).IsRequired().HasMaxLength(50);
            entity.Property(e => e.Details).HasMaxLength(1000);

            entity.HasOne(e => e.User)
                .WithMany(u => u.Events)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(e => e.Key)
                .WithMany(k => k.Events)
                .HasForeignKey(e => e.KeyId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasIndex(e => e.Timestamp);
            entity.HasIndex(e => e.ActionType);
        });
    }
}
