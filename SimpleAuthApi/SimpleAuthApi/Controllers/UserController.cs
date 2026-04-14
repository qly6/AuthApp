using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace SimpleAuthApi.Controllers
{
    [Authorize]
    [ApiController]
    [Route("[controller]")]
    public class UserController : ControllerBase
    {
        [HttpGet("profile")]
        public IActionResult GetProfile()
        {
            // Lấy thông tin từ token claims
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var username = User.FindFirstValue(ClaimTypes.Name);
            var email = User.FindFirstValue(ClaimTypes.Email);

            return Ok(new
            {
                Id = userId,
                Username = username,
                Email = email,
                Message = "Đây là thông tin từ token đã xác thực."
            });
        }
    }
}
