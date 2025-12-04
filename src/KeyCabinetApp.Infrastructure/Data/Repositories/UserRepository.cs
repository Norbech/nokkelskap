using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace KeyCabinetApp.Infrastructure.Data.Repositories;

public class UserRepository : IUserRepository
{
    private readonly ApplicationDbContext _context;

    public UserRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(int id)
    {
        return await _context.Users
            .Include(u => u.KeyAccess)
                .ThenInclude(ka => ka.Key)
            .FirstOrDefaultAsync(u => u.Id == id);
    }

    public async Task<User?> GetByUsernameAsync(string username)
    {
        return await _context.Users
            .Include(u => u.KeyAccess)
                .ThenInclude(ka => ka.Key)
            .FirstOrDefaultAsync(u => u.Username == username);
    }

    public async Task<User?> GetByRfidAsync(string rfidTag)
    {
        return await _context.Users
            .Include(u => u.KeyAccess)
                .ThenInclude(ka => ka.Key)
            .FirstOrDefaultAsync(u => u.RfidTag == rfidTag);
    }

    public async Task<IEnumerable<User>> GetAllAsync()
    {
        return await _context.Users
            .Include(u => u.KeyAccess)
                .ThenInclude(ka => ka.Key)
            .ToListAsync();
    }

    public async Task<User> AddAsync(User user)
    {
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    public async Task UpdateAsync(User user)
    {
        _context.Users.Update(user);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(int id)
    {
        var user = await _context.Users.FindAsync(id);
        if (user != null)
        {
            _context.Users.Remove(user);
            await _context.SaveChangesAsync();
        }
    }
}
