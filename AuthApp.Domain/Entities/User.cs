namespace AuthApp.Domain.Entities
{
    public class User
    {
        public Guid Id { get; set; }
        public string Email { get; set; } = default!;
        public bool IsActive { get; set; } = true;

        public UserPassword? Password { get; set; }
        public UserMfa? Mfa { get; set; }
        public ICollection<UserPasskey> Passkeys { get; set; } = new List<UserPasskey>();
    }
}
