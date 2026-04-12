using AuthApp.Application.Interfaces;
using AuthApp.Infrastructure.Security;
using AuthApp.Infrastructure.Services;
using Microsoft.Extensions.DependencyInjection;

namespace AuthApp.Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructure(this IServiceCollection services)
        {
            // ✅ MFA
            services.AddScoped<IMfaService, MfaService>();

            // ✅ Token (JWT)
            services.AddScoped<ITokenService, JwtTokenService>();

            services.AddScoped<IPasskeyService, PasskeyService>();

            return services;
        }
    }
}
