namespace AuthApp.Application.DTOs
{
    public class AuthResponse
    {
        public bool Success { get; private set; }
        public string? AccessToken { get; private set; }
        public string? RefreshToken { get; private set; }
        public string? Error { get; private set; }
        public bool RequiresMfa { get; private set; }
        public Guid? UserId { get; private set; }

        private AuthResponse() { }

        // ✅ SUCCESS
        public static AuthResponse SuccessResult(string accessToken, string refreshToken)
        {
            return new AuthResponse
            {
                Success = true,
                AccessToken = accessToken,
                RefreshToken = refreshToken
            };
        }

        // ❌ FAIL
        public static AuthResponse Fail(string error)
        {
            return new AuthResponse
            {
                Success = false,
                Error = error
            };
        }

        // 🔐 MFA REQUIRED
        public static AuthResponse RequireMfa(Guid userId)
        {
            return new AuthResponse
            {
                Success = false,
                RequiresMfa = true,
                UserId = userId
            };
        }
    }
}
