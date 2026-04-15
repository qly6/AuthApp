using Microsoft.AspNetCore.DataProtection;
using OtpNet;

namespace SimpleAuthApi.Services
{
    public class MfaService : IMfaService
    {
        private readonly IDataProtector _protector;

        public MfaService(IDataProtectionProvider provider)
        {
            _protector = provider.CreateProtector("SimpleAuth.Mfa.Secret");
        }

        public string Decrypt(string cipherText)
        {
            return _protector.Unprotect(cipherText);
        }

        public string Encrypt(string plainText)
        {
            return _protector.Protect(plainText);
        }

        public string GenerateQrCodeUri(string username, string secret, string issuer = "SimpleAuth")
        {
            return $"otpauth://totp/{issuer}:{username}?secret={secret}&issuer={issuer}";
        }

        public string GenerateTotpSecret()
        {
            var key = KeyGeneration.GenerateRandomKey(20);
            return Base32Encoding.ToString(key);
        }

        public bool ValidateTotp(string secret, string code)
        {
            if (string.IsNullOrEmpty(secret) || string.IsNullOrEmpty(code))
                return false;

            var secretBytes = Base32Encoding.ToBytes(secret);
            var totp = new Totp(secretBytes);
            long timeStepMatched;
            return totp.VerifyTotp(code, out timeStepMatched, new VerificationWindow(previous: 2, future: 2));
        }
    }
}
