using AuthApp.Application.DTOs;
using AuthApp.Application.Interfaces;
using AuthApp.Application.Services;
using Fido2NetLib;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using LoginRequest = AuthApp.Application.DTOs.LoginRequest;
using RefreshRequest = AuthApp.Application.DTOs.RefreshRequest;

namespace AuthApp.Api.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly AuthService _auth;
        private readonly IPasskeyService _passkey;

        public AuthController(AuthService auth, IPasskeyService passkey)
        {
            _auth = auth;
            _passkey = passkey;
        }

        // =========================
        // 🆕 REGISTER USER
        // =========================
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            var result = await _auth.Register(
                request.Email,
                request.Password
            );

            if (!result.Success)
                return BadRequest(result);

            return Ok(result);
        }

        // =========================
        // 🔐 PASSWORD LOGIN
        // =========================
        [HttpPost("login/password")]
        public async Task<IActionResult> LoginPassword([FromBody] LoginRequest request)
        {
            var result = await _auth.LoginPassword(
                request.Email,
                request.Password,
                request.MfaCode
            );

            if (!result.Success)
                return Unauthorized(result);

            return Ok(result);
        }

        // =========================
        // 🔄 REFRESH TOKEN
        // =========================
        [HttpPost("refresh")]
        public async Task<IActionResult> Refresh([FromBody] RefreshRequest request)
        {
            var result = await _auth.RefreshToken(request.RefreshToken);

            if (!result.Success)
                return Unauthorized(result);

            return Ok(result);
        }

        // =========================
        // 🚪 LOGOUT
        // =========================
        [HttpPost("logout")]
        public async Task<IActionResult> Logout([FromBody] RefreshRequest request)
        {
            await _auth.Logout(request.RefreshToken);
            return Ok(new { message = "Logged out" });
        }

        // =========================
        // 🔐 MFA SETUP (QR)
        // =========================
        [Authorize]
        [HttpPost("mfa/setup")]
        public async Task<IActionResult> SetupMfa()
        {
            var userId = GetUserId();

            var result = await _auth.SetupMfa(userId);

            return File(result.QrCodeImage, "image/png");
        }

        // =========================
        // 🔐 MFA VERIFY
        // =========================
        [Authorize]
        [HttpPost("mfa/verify")]
        public async Task<IActionResult> VerifyMfa([FromBody] VerifyMfaRequest request)
        {
            var userId = GetUserId();

            var success = await _auth.VerifyMfa(userId, request.Code);

            if (!success)
                return BadRequest("Invalid MFA code");

            return Ok("MFA enabled");
        }

        // =========================
        // 🔑 PASSKEY REGISTER OPTIONS
        // =========================
        [Authorize]
        [HttpPost("passkey/register/options")]
        public async Task<IActionResult> RegisterOptions()
        {
            var userId = GetUserId();

            // You may need email, so fetch from DB if needed
            var email = User.Identity?.Name ?? "user";

            var options = await _passkey.GenerateRegistrationOptions(email);

            return Ok(options);
        }

        // =========================
        // 🔑 PASSKEY REGISTER
        // =========================
        [Authorize]
        [HttpPost("passkey/register")]
        public async Task<IActionResult> Register(
            [FromBody] AuthenticatorAttestationRawResponse response)
        {
            var userId = GetUserId();

            await _passkey.RegisterCredential(userId, response);

            return Ok(new { message = "Passkey registered" });
        }

        // =========================
        // 🔑 PASSKEY LOGIN OPTIONS
        // =========================
        [HttpPost("passkey/login/options")]
        public async Task<IActionResult> LoginOptions([FromBody] string email)
        {
            var options = await _passkey.GenerateLoginOptions(email);

            return Ok(options);
        }

        // =========================
        // 🔑 PASSKEY LOGIN
        // =========================
        [HttpPost("passkey/login")]
        public async Task<IActionResult> Login(
            [FromBody] AuthenticatorAssertionRawResponse response)
        {
            var userId = await _passkey.VerifyLogin(response);

            if (userId == null)
                return Unauthorized();

            var result = await _auth.GenerateSession(userId.Value);

            return Ok(result);
        }

        // =========================
        // 🧠 HELPER: GET USER ID FROM JWT
        // =========================
        private Guid GetUserId()
        {
            var userId = User.FindFirst("sub")?.Value;

            if (string.IsNullOrEmpty(userId))
                throw new Exception("Invalid token");

            return Guid.Parse(userId);
        }

    }
}
