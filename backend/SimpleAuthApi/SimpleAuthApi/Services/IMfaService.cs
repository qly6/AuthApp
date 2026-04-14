namespace SimpleAuthApi.Services
{
    public interface IMfaService
    {
        string GenerateTotpSecret();
        string GenerateQrCodeUri(string username, string secret, string issuer = "SimpleAuth");
        bool ValidateTotp(string secret, string code);
        string Encrypt(string plainText);
        string Decrypt(string cipherText);
    }
}
