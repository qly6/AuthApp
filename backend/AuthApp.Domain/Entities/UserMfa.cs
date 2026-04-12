namespace AuthApp.Domain.Entities
{
    public class UserMfa
    {
        public Guid UserId { get; set; }
        public string Secret { get; set; } = default!;
        public bool IsEnabled { get; set; }

        public User User { get; set; } = default!;
    }
}
