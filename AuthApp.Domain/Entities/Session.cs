namespace AuthApp.Domain.Entities
{
    public class Session
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }

        public string RefreshToken { get; set; } = default!;
        public DateTime ExpiresAt { get; set; }

        public User User { get; set; } = default!;
    }
}
