namespace AuthApp.Application.DTOs
{
    public class VerifyMfaRequest
    {
        public string Code { get; set; } = default!;
    }
}
