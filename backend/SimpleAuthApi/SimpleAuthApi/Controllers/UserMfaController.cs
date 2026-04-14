using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SimpleAuthApi.Data;
using SimpleAuthApi.Models;
using SimpleAuthApi.Models.DTOs;
using SimpleAuthApi.Services;
using System.Security.Claims;

namespace SimpleAuthApi.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/user/mfa")]
    public class UserMfaController : ControllerBase
    {
        private readonly IMfaMethodManager _methodManager;
        private readonly IMfaService _mfaService;

        public UserMfaController(IMfaMethodManager methodManager, IMfaService mfaService)
        {
            _methodManager = methodManager;
            _mfaService = mfaService;
        }

        private int GetUserId() => int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        [HttpGet("methods")]
        public async Task<ActionResult<List<MfaMethodDto>>> GetMethods()
        {
            var userId = GetUserId();
            var methods = await _methodManager.GetUserMethodsAsync(userId);
            return methods.Select(m => new MfaMethodDto
            {
                Id = m.Id,
                Type = m.Type.ToString().ToLower(),
                IsEnabled = m.IsEnabled,
                CreatedAt = m.CreatedAt
            }).ToList();
        }

        [HttpPost("totp/setup")]
        public async Task<ActionResult<TotpSetupResponse>> SetupTotp()
        {
            var userId = GetUserId();
            // Check if already enabled
            var methods = await _methodManager.GetUserMethodsAsync(userId);
            if (methods.Any(m => m.Type == MfaMethodType.Totp && m.IsEnabled))
                return BadRequest("TOTP already enabled.");

            var plainSecret = _mfaService.GenerateTotpSecret();
            var method = await _methodManager.CreateTotpSetupAsync(userId, plainSecret);
            var user = await HttpContext.RequestServices.GetRequiredService<AppDbContext>()
                .Users.FindAsync(userId);
            var qrUri = _mfaService.GenerateQrCodeUri(user!.Username, plainSecret);

            return Ok(new TotpSetupResponse
            {
                MethodId = method.Id,
                Secret = plainSecret,
                QrCodeUri = qrUri
            });
        }

        [HttpPost("totp/verify")]
        public async Task<IActionResult> VerifyTotpSetup([FromBody] VerifyTotpSetupRequest request)
        {
            var userId = GetUserId();
            var success = await _methodManager.VerifyAndEnableTotpAsync(userId, request.MethodId, request.Code);
            if (!success)
                return BadRequest("Invalid verification code.");
            return Ok(new { message = "TOTP enabled successfully." });
        }

        [HttpDelete("{methodId}")]
        public async Task<IActionResult> DisableMethod(int methodId)
        {
            var userId = GetUserId();
            var success = await _methodManager.DisableMethodAsync(userId, methodId);
            if (!success)
                return NotFound();
            return Ok(new { message = "MFA method disabled." });
        }
    }
}
