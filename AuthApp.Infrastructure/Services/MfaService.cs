using AuthApp.Application.Interfaces;
using OtpNet;
using QRCoder;

namespace AuthApp.Infrastructure.Services
{
    internal class MfaService : IMfaService
    {
        private const string Issuer = "AuthApp";

        public string GenerateSecret()
        {
            var key = KeyGeneration.GenerateRandomKey(20);
            return Base32Encoding.ToString(key);
        }

        public string GenerateQrCodeUri(string email, string secret)
        {
            return $"otpauth://totp/{Issuer}:{email}?secret={secret}&issuer={Issuer}";
        }

        public byte[] GenerateQrCodeImage(string qrCodeUri)
        {
            using var qrGenerator = new QRCodeGenerator();
            var data = qrGenerator.CreateQrCode(qrCodeUri, QRCodeGenerator.ECCLevel.Q);
            var qrCode = new PngByteQRCode(data);

            return qrCode.GetGraphic(20); // PNG bytes
        }

        public bool ValidateCode(string secret, string code)
        {
            var totp = new Totp(Base32Encoding.ToBytes(secret));
            return totp.VerifyTotp(code, out _, VerificationWindow.RfcSpecifiedNetworkDelay);
        }
    }
}
