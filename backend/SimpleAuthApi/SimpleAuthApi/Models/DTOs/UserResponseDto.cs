namespace SimpleAuthApi.Models.DTOs
{
    public class UserResponseDto
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;
        public bool RequireMfa { get; set; }
        public string? MfaToken { get; set; }
        public List<string>? AvailableMethods { get; set; } // e.g., ["totp"]
    }
}
