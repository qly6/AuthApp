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

        public AuthService(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
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

            string token = GenerateJwtToken(user);

            return new UserResponseDto
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                Token = token
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
    }
}
