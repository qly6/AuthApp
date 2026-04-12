using AuthApp.Application.Interfaces;
using AuthApp.Domain.Entities;
using AuthApp.Persistence.DbContext;
using Fido2NetLib;
using Fido2NetLib.Objects;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using System.Linq;

namespace AuthApp.Infrastructure.Security
{
    internal class PasskeyService : IPasskeyService
    {
        private readonly IFido2 _fido2;
        private readonly IMemoryCache _cache;
        private readonly AppDbContext _db;


        public PasskeyService(IConfiguration config, IMemoryCache cache, AppDbContext db)
        {
            var fidoConfig = new Fido2Configuration
            {
                ServerDomain = config["Fido:Domain"],
                ServerName = "AuthApp",
                Origins = new HashSet<string> { config["Fido:Origin"] }
            };

            _fido2 = new Fido2(fidoConfig);
            _cache = cache;
            _db = db;
        }

        public async Task<AssertionOptions> GenerateLoginOptions(string email)
        {
            var user = await _db.Users
                .FirstOrDefaultAsync(x => x.Email == email);

            if (user == null)
                throw new Exception("User not found");

            // 🔑 Get user's passkeys
            var credentials = await _db.Passkeys
                .Where(x => x.UserId == user.Id)
                .Select(x => new PublicKeyCredentialDescriptor(Convert.FromBase64String(x.CredentialId)))
                .ToListAsync();

            if (credentials.Count == 0)
                throw new Exception("No passkeys registered");

            // 🧠 Build params (NEW v8+ way)
            var options = _fido2.GetAssertionOptions(
                new GetAssertionOptionsParams
                {
                    AllowedCredentials = credentials,
                    UserVerification = UserVerificationRequirement.Preferred
                }
            );

            // 💾 Store challenge for verification step
            _cache.Set(
                $"fido2.assertion.{user.Id}",
                options,
                TimeSpan.FromMinutes(5)
            );

            return options;
        }

        public async Task<CredentialCreateOptions> GenerateRegistrationOptions(string email)
        {
            var user = await _db.Users.FirstOrDefaultAsync(x => x.Email == email);

            if (user == null)
                throw new Exception("User not found");

            var fidoUser = new Fido2User
            {
                Id = user.Id.ToByteArray(),
                Name = user.Email,
                DisplayName = user.Email
            };

            var existingCredentials = await _db.Passkeys
                .Where(x => x.UserId == user.Id)
                .Select(x => new PublicKeyCredentialDescriptor(Convert.FromBase64String(x.CredentialId)))
                .ToListAsync();

            var options = _fido2.RequestNewCredential(new RequestNewCredentialParams()
              {
                User = fidoUser,
                ExcludeCredentials = existingCredentials,
                AuthenticatorSelection = AuthenticatorSelection.Default,
                AttestationPreference = AttestationConveyancePreference.None
              }
            );

            // store challenge
            _cache.Set($"fido2.attestation.{user.Id}", options, TimeSpan.FromMinutes(5));

            return options;
        }

        public async Task<bool> RegisterCredential(Guid userId, AuthenticatorAttestationRawResponse response)
        {
            var options = _cache.Get<CredentialCreateOptions>($"fido2.attestation.{userId}") ?? throw new Exception("Challenge expired");

            var credential = await _fido2.MakeNewCredentialAsync(
    new MakeNewCredentialParams
                    {
                        AttestationResponse = response,
                        OriginalOptions = options,

                        IsCredentialIdUniqueToUserCallback = async (args, ct) =>
                        {
                            return !await _db.Passkeys
                                .AnyAsync(x => Convert.FromBase64String(x.CredentialId) == args.CredentialId, ct);
                        }
                    },
    CancellationToken.None);

            var passkey = new UserPasskey
            {
                Id = Guid.NewGuid(),
                UserId = userId, // ✅ from input
                CredentialId = Convert.ToBase64String(credential.Id),
                PublicKey = Convert.ToBase64String(credential.PublicKey),
                SignCount = credential.SignCount
            };

            _db.Passkeys.Add(passkey);
            await _db.SaveChangesAsync();

            return true;
        }

        public async Task<Guid?> VerifyLogin(AuthenticatorAssertionRawResponse response)
        {
            var credentialId = WebEncoders.Base64UrlDecode(response.Id);

            // 🔍 Find passkey by CredentialId (byte[])
            var passkey = _db.Passkeys
                .AsEnumerable()
                .FirstOrDefault(x =>
                    Convert.FromBase64String(x.CredentialId).SequenceEqual(credentialId)
                );

            if (passkey == null)
                return null;

            // 📦 Get original challenge
            var options = _cache.Get<AssertionOptions>($"fido2.assertion.{passkey.UserId}");

            if (options == null)
                return null;

            // 🔐 Verify assertion (v8+ pattern)
            var result = await _fido2.MakeAssertionAsync(
                new MakeAssertionParams
                {
                    AssertionResponse = response,
                    OriginalOptions = options,
                    StoredPublicKey = Convert.FromBase64String(passkey.PublicKey),
                    StoredSignatureCounter = passkey.SignCount,

                    IsUserHandleOwnerOfCredentialIdCallback = async (args, ct) =>
                    {
                        // Optional extra validation
                        return true;
                    }
                },
                CancellationToken.None
            );

            // 🔄 Update counter (ANTI-REPLAY)
            passkey.SignCount = result.SignCount;

            await _db.SaveChangesAsync();

            return passkey.UserId;
        }
    }
}
