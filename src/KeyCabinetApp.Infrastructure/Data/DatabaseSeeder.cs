using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace KeyCabinetApp.Infrastructure.Data;

public class DatabaseSeeder
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<DatabaseSeeder> _logger;

    public DatabaseSeeder(ApplicationDbContext context, ILogger<DatabaseSeeder> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Ensures database is created and seeded with initial data
    /// </summary>
    public async Task SeedAsync()
    {
        try
        {
            // Ensure database is created
            await _context.Database.EnsureCreatedAsync();
            _logger.LogInformation("Database initialized");

            // Check if already seeded
            if (await _context.Users.AnyAsync())
            {
                _logger.LogInformation("Database already contains data, skipping seed");
                return;
            }

            _logger.LogInformation("Seeding database with initial data...");

            // Create admin user
            var adminSalt = BCrypt.Net.BCrypt.GenerateSalt(12);
            var adminHash = BCrypt.Net.BCrypt.HashPassword("admin123", adminSalt);

            var adminUser = new User
            {
                Name = "Administrator",
                Username = "admin",
                PasswordHash = adminHash,
                PasswordSalt = adminSalt,
                RfidTag = null, // Set this to your admin RFID card if you have one
                IsAdmin = true,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            _context.Users.Add(adminUser);

            // Create a test user with RFID
            var testSalt = BCrypt.Net.BCrypt.GenerateSalt(12);
            var testHash = BCrypt.Net.BCrypt.HashPassword("test123", testSalt);

            var testUser = new User
            {
                Name = "Test Bruker",
                Username = "testuser",
                PasswordHash = testHash,
                PasswordSalt = testSalt,
                RfidTag = "1234567890", // Replace with actual test RFID card
                IsAdmin = false,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            _context.Users.Add(testUser);

            // Create example keys
            var keys = new List<Key>
            {
                new Key
                {
                    SlotId = 1,
                    Name = "Ambulanse nøkkel",
                    Description = "Nøkkel til ambulanse 1",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Key
                {
                    SlotId = 2,
                    Name = "Bil 3 nøkkel",
                    Description = "Nøkkel til tjenestebil 3",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Key
                {
                    SlotId = 3,
                    Name = "Hovedinngang",
                    Description = "Nøkkel til hovedinngangen",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Key
                {
                    SlotId = 4,
                    Name = "Lager",
                    Description = "Nøkkel til lagerrommet",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Key
                {
                    SlotId = 5,
                    Name = "Kontor",
                    Description = "Nøkkel til kontoret",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                }
            };

            _context.Keys.AddRange(keys);
            await _context.SaveChangesAsync();

            // Give admin access to all keys
            foreach (var key in keys)
            {
                _context.UserKeyAccess.Add(new UserKeyAccess
                {
                    UserId = adminUser.Id,
                    KeyId = key.Id,
                    GrantedAt = DateTime.UtcNow
                });
            }

            // Give test user access to keys 1, 2, and 3
            for (int i = 0; i < 3 && i < keys.Count; i++)
            {
                _context.UserKeyAccess.Add(new UserKeyAccess
                {
                    UserId = testUser.Id,
                    KeyId = keys[i].Id,
                    GrantedAt = DateTime.UtcNow
                });
            }

            await _context.SaveChangesAsync();

            _logger.LogInformation("Database seeded successfully");
            _logger.LogInformation("Admin user created - Username: admin, Password: admin123");
            _logger.LogInformation("Test user created - Username: testuser, Password: test123, RFID: 1234567890");
            _logger.LogInformation("Created {KeyCount} example keys", keys.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error seeding database");
            throw;
        }
    }
}
