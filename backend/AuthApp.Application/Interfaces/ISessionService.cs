namespace AuthApp.Application.Interfaces
{
    public interface ISessionService
    {
        Task CreateSessionAsync(Guid userId, string refreshToken);
        Task<bool> ValidateRefreshTokenAsync(string refreshToken);
        Task RevokeSessionAsync(string refreshToken);
    }
}
