namespace AuthApp.Domain.Entities
{
    public class UserPasskey
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }

        public string CredentialId { get; set; } = default!;
        public string PublicKey { get; set; } = default!;
        public uint SignCount { get; set; }
    }
}
