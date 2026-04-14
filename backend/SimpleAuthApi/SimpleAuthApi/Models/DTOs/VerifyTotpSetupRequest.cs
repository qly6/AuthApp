namespace SimpleAuthApi.Models.DTOs
{
    public class VerifyTotpSetupRequest
    {
        public int MethodId { get; set; }
        public string Code { get; set; } = string.Empty;
    }
}
