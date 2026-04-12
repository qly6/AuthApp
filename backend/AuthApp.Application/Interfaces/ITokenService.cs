namespace AuthApp.Application.Interfaces
{
    public interface ITokenService
    {
        string GenerateAccessToken(Guid userId);
        string GenerateRefreshToken();
    }
}
