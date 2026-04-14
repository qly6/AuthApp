using SimpleAuthApi.Models.DTOs;

namespace SimpleAuthApi.Services
{
    public interface IAuthService
    {
        Task<UserResponseDto?> RegisterAsync(RegisterDto registerDto);
        Task<UserResponseDto?> LoginAsync(LoginDto loginDto);
        Task<UserResponseDto> VerifyMfaAsync(VerifyMfaRequest request);
    }
}
