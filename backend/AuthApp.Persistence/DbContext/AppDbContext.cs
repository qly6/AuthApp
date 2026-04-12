using AuthApp.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace AuthApp.Persistence.DbContext
{
    public class AppDbContext : Microsoft.EntityFrameworkCore.DbContext
    {
        public DbSet<User> Users => Set<User>();
        public DbSet<UserPassword> Passwords => Set<UserPassword>();
        public DbSet<UserPasskey> Passkeys => Set<UserPasskey>();
        public DbSet<UserMfa> Mfas => Set<UserMfa>();
        public DbSet<Session> Sessions => Set<Session>();

        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options) { }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            builder.Entity<User>(e =>
            {
                e.HasKey(x => x.Id);
                e.HasIndex(x => x.Email).IsUnique();
            });

            builder.Entity<UserPassword>(e =>
            {
                e.HasKey(x => x.UserId);
                e.HasOne(x => x.User)
                 .WithOne(u => u.Password)
                 .HasForeignKey<UserPassword>(x => x.UserId);
            });

            builder.Entity<UserPasskey>(e =>
            {
                e.HasKey(x => x.Id);
                e.HasIndex(x => x.CredentialId).IsUnique();
            });

            builder.Entity<UserMfa>(e =>
            {
                e.HasKey(x => x.UserId);
            });

            builder.Entity<Session>(e =>
            {
                e.HasKey(x => x.Id);
            });
        }
    }
}
