namespace SimpleAuthApi.Models.DTOs
{
    public class TotpSetupResponse
    {
        public int MethodId { get; set; }
        public string Secret { get; set; } = string.Empty;
        public string QrCodeUri { get; set; } = string.Empty;
    }
}
