using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace KeyCabinetApp.Infrastructure.Data.Repositories;

public class KeyRepository : IKeyRepository
{
    private readonly ApplicationDbContext _context;

    public KeyRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Key?> GetByIdAsync(int id)
    {
        return await _context.Keys
            .AsNoTracking()
            .Include(k => k.UserAccess)
                .ThenInclude(ua => ua.User)
            .FirstOrDefaultAsync(k => k.Id == id);
    }

    public async Task<Key?> GetBySlotIdAsync(int slotId)
    {
        return await _context.Keys
            .AsNoTracking()
            .Include(k => k.UserAccess)
                .ThenInclude(ua => ua.User)
            .FirstOrDefaultAsync(k => k.SlotId == slotId);
    }

    public async Task<IEnumerable<Key>> GetAllAsync()
    {
        return await _context.Keys
            .AsNoTracking()
            .Include(k => k.UserAccess)
                .ThenInclude(ua => ua.User)
            .ToListAsync();
    }

    public async Task<IEnumerable<Key>> GetActiveKeysAsync()
    {
        return await _context.Keys
            .AsNoTracking()
            .Where(k => k.IsActive)
            .Include(k => k.UserAccess)
                .ThenInclude(ua => ua.User)
            .ToListAsync();
    }

    public async Task<IEnumerable<Key>> GetKeysForUserAsync(int userId)
    {
        return await _context.UserKeyAccess
            .AsNoTracking()
            .Where(ua => ua.UserId == userId)
            .Include(ua => ua.Key)
            .Select(ua => ua.Key)
            .Where(k => k.IsActive)
            .ToListAsync();
    }

    public async Task<Key> AddAsync(Key key)
    {
        _context.Keys.Add(key);
        await _context.SaveChangesAsync();
        return key;
    }

    public async Task UpdateAsync(Key key)
    {
        var existingKey = await _context.Keys.FindAsync(key.Id);
        if (existingKey != null)
        {
            _context.Entry(existingKey).CurrentValues.SetValues(key);
            await _context.SaveChangesAsync();
        }
    }

    public async Task DeleteAsync(int id)
    {
        var key = await _context.Keys.FindAsync(id);
        if (key != null)
        {
            _context.Keys.Remove(key);
            await _context.SaveChangesAsync();
        }
    }
}
