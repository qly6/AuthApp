namespace SimpleAuthApi.Models
{
    public enum MfaMethodType
    {
        Totp = 1
        // Sms, Email later
    }

    public class MfaMethod
    {
        public int Id { get; set; }

        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public MfaMethodType Type { get; set; }

        public bool IsEnabled { get; set; }

        // Encrypted secret (for TOTP) or other data for future types
        public string? Secret { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? LastUsedAt { get; set; }
    }
}
