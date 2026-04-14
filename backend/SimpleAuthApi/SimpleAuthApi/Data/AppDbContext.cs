using Microsoft.EntityFrameworkCore;
using SimpleAuthApi.Models;

namespace SimpleAuthApi.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<User> Users { get; set; }
        public DbSet<MfaMethod> MfaMethods => Set<MfaMethod>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Unique constraint per user per type (optional)
            modelBuilder.Entity<MfaMethod>()
                .HasIndex(m => new { m.UserId, m.Type })
                .IsUnique();

            base.OnModelCreating(modelBuilder);
        }
    }
}
