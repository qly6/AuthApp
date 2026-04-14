using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SimpleAuthApi.Data;
using SimpleAuthApi.Models;
using SimpleAuthApi.Models.DTOs;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace SimpleAuthApi.Services
{
    public class AuthService : IAuthService
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly IMfaMethodManager _mfaMethodManager;
        private readonly IMfaService _mfaService;

        public AuthService(AppDbContext context, IConfiguration configuration, IMfaMethodManager mfaMethodManager, IMfaService mfaService)
        {
            _context = context;
            _configuration = configuration;
            _mfaMethodManager = mfaMethodManager;
            _mfaService = mfaService;
        }

        public async Task<UserResponseDto?> LoginAsync(LoginDto loginDto)
        {
            var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Username == loginDto.Username);

            if (user == null)
                return null;

            // Xác minh mật khẩu
            bool passwordValid = BCrypt.Net.BCrypt.Verify(loginDto.Password, user.PasswordHash);
            if (!passwordValid)
                return null;

            bool hasMfa = await _mfaMethodManager.HasAnyEnabledMethodAsync(user.Id);

            string token = string.Empty;
            List<MfaMethod> methods = new List<MfaMethod>();
            List<string> enabledTypes = new List<string>();
            if (!hasMfa)
            {
                token = GenerateJwtToken(user);
            }
            else
            {
                // MFA required
                methods = await _mfaMethodManager.GetUserMethodsAsync(user.Id);
                enabledTypes = methods.Where(m => m.IsEnabled)
                                           .Select(m => m.Type.ToString().ToLower())
                                           .ToList();

                token = GenerateMfaToken(user);
            }

            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                Token = token,
                RequireMfa = hasMfa,
                AvailableMethods = enabledTypes,
                MfaToken = hasMfa ? token : string.Empty,
            };
        }

        public async Task<UserResponseDto?> RegisterAsync(RegisterDto registerDto)
        {
            // Kiểm tra username hoặc email đã tồn tại
            if (await _context.Users.AnyAsync(u => u.Username == registerDto.Username || u.Email == registerDto.Email))
                return null;

            // Hash password bằng BCrypt
            string passwordHash = BCrypt.Net.BCrypt.HashPassword(registerDto.Password);

            var user = new User
            {
                Username = registerDto.Username,
                Email = registerDto.Email,
                PasswordHash = passwordHash
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            // Tạo JWT token cho user mới
            string token = GenerateJwtToken(user);

            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                Token = token
            };
        }

        public async Task<UserResponseDto> VerifyMfaAsync(VerifyMfaRequest request)
        {
            // Validate MFA token
            var principal = ValidateMfaToken(request.MfaToken);
            if (principal == null)
                throw new UnauthorizedAccessException("Invalid or expired MFA token.");

            var userIdClaim = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdClaim, out int userId))
                throw new UnauthorizedAccessException("Invalid token claims.");

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                throw new UnauthorizedAccessException("User not found.");

            // Check method type (currently only TOTP supported)
            if (!request.MethodType.Equals("totp", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Unsupported MFA method.");

            var methods = await _mfaMethodManager.GetUserMethodsAsync(userId);
            var totpMethod = methods.FirstOrDefault(m => m.Type == MfaMethodType.Totp && m.IsEnabled);
            if (totpMethod == null)
                throw new InvalidOperationException("TOTP is not enabled for this user.");

            var plainSecret = _mfaService.Decrypt(totpMethod.Secret!);
            if (!_mfaService.ValidateTotp(plainSecret, request.Code))
                throw new UnauthorizedAccessException("Invalid verification code.");

            // Update last used timestamp
            totpMethod.LastUsedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            string token = GenerateMfaToken(user);

            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                Token = token,
                RequireMfa = true,
                AvailableMethods = methods.Where(x=>x.IsEnabled).Select(m => m.Type.ToString().ToLower()).ToList(),
                MfaToken = token,
            };
        }

        private ClaimsPrincipal? ValidateMfaToken(string token)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = Encoding.ASCII.GetBytes(_configuration["Jwt:Key"]);

            try
            {
                var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                    ValidateIssuer = false,
                    ValidateAudience = false,
                    ClockSkew = TimeSpan.Zero
                }, out SecurityToken validatedToken);

                var mfaClaim = principal.FindFirst("mfa_required");
                if (mfaClaim == null || !string.Equals(mfaClaim.Value, "true", StringComparison.OrdinalIgnoreCase))
                    return null;

                return principal;
            }
            catch
            {
                return null;
            }
        }

        private string GenerateJwtToken(User user)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = Encoding.ASCII.GetBytes(_configuration["Jwt:Key"]!);

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Username),
                new Claim(ClaimTypes.Email, user.Email)
            }),
                Expires = DateTime.UtcNow.AddDays(7),
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(key),
                    SecurityAlgorithms.HmacSha256Signature)
            };

            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }

        // Helper methods for JWT (keep existing GenerateJwtToken)
        private string GenerateMfaToken(User user)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = Encoding.ASCII.GetBytes(_configuration["Jwt:Key"]);
            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                    new Claim(ClaimTypes.Name, user.Username),
                    new Claim(ClaimTypes.Email, user.Email),
                    new Claim("mfa_required", "true")
                }),
                Expires = DateTime.UtcNow.AddDays(7),
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(key),
                    SecurityAlgorithms.HmacSha256Signature)
            };
            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }

    }
}
