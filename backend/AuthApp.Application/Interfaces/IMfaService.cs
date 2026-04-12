namespace AuthApp.Application.Interfaces
{
    public interface IMfaService
    {
        string GenerateSecret();
        string GenerateQrCodeUri(string email, string secret);
        byte[] GenerateQrCodeImage(string qrCodeUri);
        bool ValidateCode(string secret, string code);
    }
}
