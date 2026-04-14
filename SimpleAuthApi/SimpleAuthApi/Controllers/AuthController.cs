using Microsoft.AspNetCore.Mvc;
using SimpleAuthApi.Models.DTOs;
using SimpleAuthApi.Services;

namespace SimpleAuthApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly ILogger<AuthController> _logger;
        private readonly IAuthService _authService;

        public AuthController(ILogger<AuthController> logger, IAuthService authService)
        {
            _logger = logger;
            _authService = authService;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register(RegisterDto registerDto)
        {
            var result = await _authService.RegisterAsync(registerDto);
            if (result == null)
                return BadRequest(new { message = "Username hoặc Email đã tồn tại." });

            return Ok(result);
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login(LoginDto loginDto)
        {
            var result = await _authService.LoginAsync(loginDto);
            if (result == null)
                return Unauthorized(new { message = "Username hoặc mật khẩu không đúng." });

            return Ok(result);
        }

        [HttpPost("logout")]
        public IActionResult Logout()
        {
            // JWT là stateless, logout được thực hiện phía client bằng cách xóa token.
            // Ở đây chỉ trả về thông báo thành công.
            return Ok(new { message = "Đăng xuất thành công. Vui lòng xóa token ở phía client." });
        }
    }
}
