using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace KeyCabinetApp.Infrastructure.Data.Repositories;

public class EventRepository : IEventRepository
{
    private readonly ApplicationDbContext _context;

    public EventRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Event> AddAsync(Event eventLog)
    {
        _context.Events.Add(eventLog);
        await _context.SaveChangesAsync();
        return eventLog;
    }

    public async Task<IEnumerable<Event>> GetAllAsync()
    {
        return await _context.Events
            .Include(e => e.User)
            .Include(e => e.Key)
            .OrderByDescending(e => e.Timestamp)
            .ToListAsync();
    }

    public async Task<IEnumerable<Event>> GetByUserIdAsync(int userId)
    {
        return await _context.Events
            .Where(e => e.UserId == userId)
            .Include(e => e.User)
            .Include(e => e.Key)
            .OrderByDescending(e => e.Timestamp)
            .ToListAsync();
    }

    public async Task<IEnumerable<Event>> GetByKeyIdAsync(int keyId)
    {
        return await _context.Events
            .Where(e => e.KeyId == keyId)
            .Include(e => e.User)
            .Include(e => e.Key)
            .OrderByDescending(e => e.Timestamp)
            .ToListAsync();
    }

    public async Task<IEnumerable<Event>> GetByDateRangeAsync(DateTime startDate, DateTime endDate)
    {
        return await _context.Events
            .Where(e => e.Timestamp >= startDate && e.Timestamp <= endDate)
            .Include(e => e.User)
            .Include(e => e.Key)
            .OrderByDescending(e => e.Timestamp)
            .ToListAsync();
    }

    public async Task<IEnumerable<Event>> GetByFilterAsync(
        int? userId, 
        int? keyId, 
        string? actionType, 
        DateTime? startDate, 
        DateTime? endDate)
    {
        var query = _context.Events
            .Include(e => e.User)
            .Include(e => e.Key)
            .AsQueryable();

        if (userId.HasValue)
            query = query.Where(e => e.UserId == userId.Value);

        if (keyId.HasValue)
            query = query.Where(e => e.KeyId == keyId.Value);

        if (!string.IsNullOrEmpty(actionType))
            query = query.Where(e => e.ActionType == actionType);

        if (startDate.HasValue)
            query = query.Where(e => e.Timestamp >= startDate.Value);

        if (endDate.HasValue)
            query = query.Where(e => e.Timestamp <= endDate.Value);

        return await query.OrderByDescending(e => e.Timestamp).ToListAsync();
    }
}
