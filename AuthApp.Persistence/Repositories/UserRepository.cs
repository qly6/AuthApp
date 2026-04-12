using AuthApp.Application.Interfaces;
using AuthApp.Domain.Entities;
using AuthApp.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace AuthApp.Persistence.Repositories
{
    public class UserRepository : IUserRepository
    {
        private readonly AppDbContext _db;

        public UserRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<User> CreateUserWithPassword(string email, string passwordHash)
        {
            var user = new User
            {
                Id = Guid.NewGuid(),
                Email = email,
                IsActive = true
            };

            var userPassword = new UserPassword
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                PasswordHash = passwordHash
            };

            user.Password = userPassword;

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            return user;
        }

        public async Task<User?> GetByEmailAsync(string email)
        {
            return await _db.Users
                .Include(x => x.Password)
                .Include(x => x.Mfa)
                .Include(x => x.Passkeys)
                .FirstOrDefaultAsync(x => x.Email == email);
        }

        public async Task<User?> GetByIdAsync(Guid id)
        {
            return await _db.Users.FindAsync(id);
        }

        public Task SaveChangesAsync()
            => _db.SaveChangesAsync();
    }
}
