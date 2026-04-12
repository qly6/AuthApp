namespace AuthApp.Application.DTOs
{
    public class LoginRequest
    {
        public string Email { get; set; } = default!;
        public string Password { get; set; } = default!;
        public string? MfaCode { get; set; }
    }
}
