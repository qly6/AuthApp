using AuthApp.Domain.Entities;

namespace AuthApp.Application.Interfaces
{
    public interface IUserRepository
    {
        Task<User?> GetByEmailAsync(string email);
        Task<User?> GetByIdAsync(Guid id);
        Task SaveChangesAsync();
        Task<User> CreateUserWithPassword(string email, string passwordHash);
    }
}
