using AuthApp.Application.DTOs;
using AuthApp.Application.Interfaces;
using AuthApp.Domain.Entities;

namespace AuthApp.Application.Services
{
    public class AuthService
    {
        private readonly IUserRepository _users;
        private readonly ITokenService _tokens;
        private readonly ISessionService _sessions;
        private readonly IMfaService _mfa;

        public AuthService(IUserRepository users, ITokenService tokens, ISessionService sessions, IMfaService mfa)
        {
            _users = users;
            _tokens = tokens;
            _sessions = sessions;
            _mfa = mfa;
        }

        // 🔐 LOGIN (PASSWORD + MFA)
        public async Task<AuthResponse> LoginPassword(
            string email,
            string password,
            string? mfaCode)
        {
            var user = await _users.GetByEmailAsync(email);

            if (user == null || user.Password == null)
                return AuthResponse.Fail("Invalid credentials");

            // Verify password
            if (!BCrypt.Net.BCrypt.Verify(password, user.Password.PasswordHash))
                return AuthResponse.Fail("Invalid credentials");

            // MFA required
            if (user.Mfa?.IsEnabled == true)
            {
                if (string.IsNullOrEmpty(mfaCode))
                    return AuthResponse.Fail("MFA required");

                if (!_mfa.ValidateCode(user.Mfa.Secret, mfaCode))
                    return AuthResponse.Fail("Invalid MFA code");
            }

            return await GenerateSession(user.Id);
        }

        // 🔄 REFRESH TOKEN
        public async Task<AuthResponse> RefreshToken(string refreshToken)
        {
            var isValid = await _sessions.ValidateRefreshTokenAsync(refreshToken);

            if (!isValid)
                return AuthResponse.Fail("Invalid refresh token");

            // ⚠️ In real case, you should map refreshToken → userId
            // Simplified here:
            var user = await _users.GetByIdAsync(Guid.Empty);

            if (user == null)
                return AuthResponse.Fail("User not found");

            return await GenerateSession(user.Id);
        }

        // 🚪 LOGOUT
        public async Task Logout(string refreshToken)
        {
            await _sessions.RevokeSessionAsync(refreshToken);
        }

        // 🔐 MFA SETUP
        public async Task<(byte[] QrCodeImage, string Secret)> SetupMfa(Guid userId)
        {
            var user = await _users.GetByIdAsync(userId);

            if (user == null)
                throw new Exception("User not found");

            var secret = _mfa.GenerateSecret();

            user.Mfa = new UserMfa
            {
                UserId = userId,
                Secret = secret,
                IsEnabled = false
            };

            await _users.SaveChangesAsync();

            var uri = _mfa.GenerateQrCodeUri(user.Email, secret);
            var qr = _mfa.GenerateQrCodeImage(uri);

            return (qr, secret);
        }

        // 🔐 MFA VERIFY
        public async Task<bool> VerifyMfa(Guid userId, string code)
        {
            var user = await _users.GetByIdAsync(userId);

            if (user?.Mfa == null)
                return false;

            var valid = _mfa.ValidateCode(user.Mfa.Secret, code);

            if (!valid)
                return false;

            user.Mfa.IsEnabled = true;
            await _users.SaveChangesAsync();

            return true;
        }

        // 🧠 PRIVATE: Generate Tokens + Session
        public async Task<AuthResponse> GenerateSession(Guid userId)
        {
            var accessToken = _tokens.GenerateAccessToken(userId);
            var refreshToken = _tokens.GenerateRefreshToken();

            await _sessions.CreateSessionAsync(userId, refreshToken);

            return AuthResponse.SuccessResult(accessToken, refreshToken);
        }

        public async Task<AuthResponse> Register(string email, string password)
        {
            var exists = await _users.GetByEmailAsync(email) != null;

            if (exists)
                return AuthResponse.Fail("Email already exists");

            var hash = BCrypt.Net.BCrypt.HashPassword(password);

            var user = await _users.CreateUserWithPassword(email, hash);

            return await GenerateSession(user.Id);
        }
    }
}
