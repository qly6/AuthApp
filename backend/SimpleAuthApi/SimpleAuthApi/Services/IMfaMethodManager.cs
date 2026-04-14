using SimpleAuthApi.Models;

namespace SimpleAuthApi.Services
{
    public interface IMfaMethodManager
    {
        Task<List<MfaMethod>> GetUserMethodsAsync(int userId);
        Task<MfaMethod?> GetMethodAsync(int userId, int methodId);
        Task<MfaMethod> CreateTotpSetupAsync(int userId, string plainSecret);
        Task<bool> VerifyAndEnableTotpAsync(int userId, int methodId, string code);
        Task<bool> DisableMethodAsync(int userId, int methodId);
        Task<bool> HasAnyEnabledMethodAsync(int userId);
    }
}
