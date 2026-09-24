using Amazon.Rekognition;
using Amazon.S3;
using CocoRider.Infrastructure.DocumentChecks;
using CocoRider.Infrastructure.Persistence;
using CocoRider.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CocoRider.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = BuildConnectionString(configuration);

        services.AddDbContext<CocoRiderDbContext>(options => options
            .UseNpgsql(connectionString, npgsql => npgsql.UseNetTopologySuite())
            .UseSnakeCaseNamingConvention());

        var storageSection = configuration.GetSection("Storage");
        services.Configure<StorageOptions>(storageSection);

        if (string.Equals(storageSection["Mode"], "Fake", StringComparison.OrdinalIgnoreCase))
        {
            services.AddSingleton<IDocumentStorage, FakeDocumentStorage>();
            services.AddSingleton<IDocumentChecker, AcceptAllDocumentChecker>();
        }
        else
        {
            // Region and credentials come from the ECS task role / environment.
            services.AddSingleton<IAmazonS3, AmazonS3Client>();
            services.AddSingleton<IAmazonRekognition, AmazonRekognitionClient>();
            services.AddSingleton<IDocumentStorage, S3DocumentStorage>();
            services.AddSingleton<IDocumentChecker, RekognitionDocumentChecker>();
        }

        return services;
    }

    /// <summary>
    /// Locally a full "ConnectionStrings:Postgres" is used. In AWS, ECS injects the fields of the
    /// RDS-managed secret as Database__Host, Database__Username, Database__Password...
    /// </summary>
    private static string BuildConnectionString(IConfiguration configuration)
    {
        var database = configuration.GetSection("Database");
        if (database["Host"] is { Length: > 0 } host)
        {
            return new NpgsqlConnectionStringBuilder
            {
                Host = host,
                Port = int.TryParse(database["Port"], out var port) ? port : 5432,
                Database = database["Name"] ?? "cocorider",
                Username = database["Username"],
                Password = database["Password"],
                // RDS enforces TLS; "Disable" is only for a local container.
                SslMode = Enum.TryParse<SslMode>(database["SslMode"], out var sslMode) ? sslMode : SslMode.Require,

                // Kerberos is never used; skipping it avoids loading libgssapi in the chiseled image.
                GssEncryptionMode = GssEncryptionMode.Disable,
            }.ConnectionString;
        }

        return configuration.GetConnectionString("Postgres")
            ?? throw new InvalidOperationException("Configure either ConnectionStrings:Postgres or Database:Host.");
    }
}
