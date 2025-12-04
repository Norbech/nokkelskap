using KeyCabinetApp.Core.Entities;

namespace KeyCabinetApp.Core.Interfaces;

public interface IKeyRepository
{
    Task<Key?> GetByIdAsync(int id);
    Task<Key?> GetBySlotIdAsync(int slotId);
    Task<IEnumerable<Key>> GetAllAsync();
    Task<IEnumerable<Key>> GetActiveKeysAsync();
    Task<IEnumerable<Key>> GetKeysForUserAsync(int userId);
    Task<Key> AddAsync(Key key);
    Task UpdateAsync(Key key);
    Task DeleteAsync(int id);
}
