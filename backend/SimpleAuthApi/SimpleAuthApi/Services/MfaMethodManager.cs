using Microsoft.EntityFrameworkCore;
using SimpleAuthApi.Data;
using SimpleAuthApi.Models;

namespace SimpleAuthApi.Services
{
    public class MfaMethodManager : IMfaMethodManager
    {
        private readonly AppDbContext _context;
        private readonly IMfaService _mfaService;

        public MfaMethodManager(AppDbContext context, IMfaService mfaService)
        {
            _context = context;
            _mfaService = mfaService;
        }

        public async Task<MfaMethod> CreateTotpSetupAsync(int userId, string plainSecret)
        {
            // Ensure user doesn't already have an enabled TOTP method
            var existing = await _context.MfaMethods
                .FirstOrDefaultAsync(m => m.UserId == userId && m.Type == MfaMethodType.Totp);
            if (existing != null && existing.IsEnabled)
                throw new InvalidOperationException("TOTP already enabled.");

            if (existing != null)
            {
                await this.DisableMethodAsync(userId, existing.Id);
            }

            var method = new MfaMethod
            {
                UserId = userId,
                Type = MfaMethodType.Totp,
                IsEnabled = false,
                Secret = _mfaService.Encrypt(plainSecret),
                CreatedAt = DateTime.UtcNow
            };

            _context.MfaMethods.Add(method);
            await _context.SaveChangesAsync();
            return method;
        }

        public async Task<bool> DisableMethodAsync(int userId, int methodId)
        {
            var method = await GetMethodAsync(userId, methodId);
            if (method == null)
                return false;

            _context.MfaMethods.Remove(method);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<MfaMethod?> GetMethodAsync(int userId, int methodId)
        {
            return await _context.MfaMethods
                .FirstOrDefaultAsync(m => m.Id == methodId && m.UserId == userId);
        }

        public async Task<List<MfaMethod>> GetUserMethodsAsync(int userId)
        {
            return await _context.MfaMethods
                .Where(m => m.UserId == userId)
                .ToListAsync();
        }

        public async Task<bool> HasAnyEnabledMethodAsync(int userId)
        {
            return await _context.MfaMethods
                .AnyAsync(m => m.UserId == userId && m.IsEnabled);
        }

        public async Task<bool> VerifyAndEnableTotpAsync(int userId, int methodId, string code)
        {
            var method = await _context.MfaMethods
                 .FirstOrDefaultAsync(m => m.Id == methodId && m.UserId == userId && m.Type == MfaMethodType.Totp);
            if (method == null || method.IsEnabled)
                return false;

            var plainSecret = _mfaService.Decrypt(method.Secret!);
            if (_mfaService.ValidateTotp(plainSecret, code))
            {
                method.IsEnabled = true;
                await _context.SaveChangesAsync();
                return true;
            }
            return false;
        }
    }
}
