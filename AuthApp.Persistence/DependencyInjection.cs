using AuthApp.Application.Interfaces;
using AuthApp.Application.Services;
using AuthApp.Persistence.DbContext;
using AuthApp.Persistence.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AuthApp.Persistence
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddPersistence(this IServiceCollection services, IConfiguration configuration)
        {
            // ✅ DbContext
            services.AddDbContext<AppDbContext>(options =>
                options.UseNpgsql(configuration.GetConnectionString("Default")));

            // ✅ Repositories
            services.AddScoped<IUserRepository, UserRepository>();

            // ✅ Services
            services.AddScoped<ISessionService, SessionService>();

            return services;
        }
    }
}
