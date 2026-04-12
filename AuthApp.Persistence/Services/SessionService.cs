using AuthApp.Application.Interfaces;
using AuthApp.Domain.Entities;
using AuthApp.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace AuthApp.Application.Services
{
    public class SessionService : ISessionService
    {
        private readonly AppDbContext _db;

        public SessionService(AppDbContext db)
        {
            _db = db;
        }

        public async Task CreateSessionAsync(Guid userId, string refreshToken)
        {
            var session = new Session
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                RefreshToken = refreshToken,
                ExpiresAt = DateTime.UtcNow.AddDays(7)
            };

            _db.Sessions.Add(session);
            await _db.SaveChangesAsync();
        }

        public async Task<bool> ValidateRefreshTokenAsync(string refreshToken)
        {
            return await _db.Sessions
                .AnyAsync(x => x.RefreshToken == refreshToken &&
                               x.ExpiresAt > DateTime.UtcNow);
        }

        public async Task RevokeSessionAsync(string refreshToken)
        {
            var session = await _db.Sessions
                .FirstOrDefaultAsync(x => x.RefreshToken == refreshToken);

            if (session != null)
            {
                _db.Sessions.Remove(session);
                await _db.SaveChangesAsync();
            }
        }
    }
}
