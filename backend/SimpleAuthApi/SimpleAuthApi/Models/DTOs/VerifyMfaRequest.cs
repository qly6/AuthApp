namespace SimpleAuthApi.Models.DTOs
{
    public class VerifyMfaRequest
    {
        public string MfaToken { get; set; } = string.Empty;
        public string MethodType { get; set; } = string.Empty; // "totp"
        public string Code { get; set; } = string.Empty;
    }
}
