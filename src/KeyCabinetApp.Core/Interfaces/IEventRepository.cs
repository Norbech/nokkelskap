using KeyCabinetApp.Core.Entities;

namespace KeyCabinetApp.Core.Interfaces;

public interface IEventRepository
{
    Task<Event> AddAsync(Event eventLog);
    Task<IEnumerable<Event>> GetAllAsync();
    Task<IEnumerable<Event>> GetByUserIdAsync(int userId);
    Task<IEnumerable<Event>> GetByKeyIdAsync(int keyId);
    Task<DateTime?> GetLastSuccessfulKeyOpenUtcAsync(int keyId);
    Task<IEnumerable<Event>> GetByDateRangeAsync(DateTime startDate, DateTime endDate);
    Task<IEnumerable<Event>> GetByFilterAsync(int? userId, int? keyId, string? actionType, DateTime? startDate, DateTime? endDate);
}
