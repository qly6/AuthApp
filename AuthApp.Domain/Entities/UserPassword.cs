namespace AuthApp.Domain.Entities
{
    public class UserPassword
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public string PasswordHash { get; set; } = default!;
        public DateTime UpdatedAt { get; set; }

        public User User { get; set; } = default!;
    }
}
