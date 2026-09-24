using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace CocoRider.Infrastructure.Persistence;

/// <summary>Used by "dotnet ef migrations add"; no database connection is opened.</summary>
internal sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<CocoRiderDbContext>
{
    public CocoRiderDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<CocoRiderDbContext>()
            .UseNpgsql("Host=localhost;Database=cocorider", npgsql => npgsql.UseNetTopologySuite())
            .UseSnakeCaseNamingConvention()
            .Options;
        return new CocoRiderDbContext(options);
    }
}
