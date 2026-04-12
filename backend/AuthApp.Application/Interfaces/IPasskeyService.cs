using Fido2NetLib;

namespace AuthApp.Application.Interfaces
{
    public interface IPasskeyService
    {
        Task<CredentialCreateOptions> GenerateRegistrationOptions(string email);
        Task<bool> RegisterCredential(Guid UserId, AuthenticatorAttestationRawResponse response);

        Task<AssertionOptions> GenerateLoginOptions(string email);
        Task<Guid?> VerifyLogin(AuthenticatorAssertionRawResponse response);
    }
}
