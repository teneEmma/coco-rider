using CocoRider.Domain.Bookings;
using CocoRider.Domain.Messaging;
using CocoRider.Domain.Notifications;
using CocoRider.Domain.Reviews;
using CocoRider.Domain.Tracking;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Vehicles;
using CocoRider.Domain.Verification;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Infrastructure.Persistence;

public sealed class CocoRiderDbContext(DbContextOptions<CocoRiderDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Strike> Strikes => Set<Strike>();
    public DbSet<UserDocument> Documents => Set<UserDocument>();
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<Trip> Trips => Set<Trip>();
    public DbSet<Booking> Bookings => Set<Booking>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<TripPosition> TripPositions => Set<TripPosition>();
    public DbSet<TripShare> TripShares => Set<TripShare>();

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        // Enums are stored as text: readable in SQL and safe when members are reordered.
        Type[] enums =
        [
            typeof(Language), typeof(Gender), typeof(VerificationStatus), typeof(StrikeReason),
            typeof(DocumentType), typeof(DocumentStatus), typeof(TripKind), typeof(TripStatus),
            typeof(BookingStatus), typeof(PaymentMethod), typeof(DevicePlatform),
        ];
        foreach (var type in enums)
            configurationBuilder.Properties(type).HaveConversion<string>().HaveMaxLength(32);
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasPostgresExtension("postgis");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(CocoRiderDbContext).Assembly);
    }
}
