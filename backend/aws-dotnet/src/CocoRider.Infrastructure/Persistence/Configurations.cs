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
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CocoRider.Infrastructure.Persistence;

internal sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.HasKey(u => u.Id);
        builder.Property(u => u.CognitoSub).HasMaxLength(64);
        builder.Property(u => u.PhoneNumber).HasMaxLength(20);
        builder.Property(u => u.FirstName).HasMaxLength(100);
        builder.Property(u => u.LastName).HasMaxLength(100);
        builder.Property(u => u.SuspensionReason).HasMaxLength(500);
        builder.HasIndex(u => u.CognitoSub).IsUnique();
        builder.HasIndex(u => u.PhoneNumber).IsUnique();

        builder.HasMany(u => u.Strikes).WithOne().HasForeignKey(s => s.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.Navigation(u => u.Strikes).UsePropertyAccessMode(PropertyAccessMode.Field);
    }
}

internal sealed class StrikeConfiguration : IEntityTypeConfiguration<Strike>
{
    public void Configure(EntityTypeBuilder<Strike> builder)
    {
        builder.HasKey(s => s.Id);
        builder.HasIndex(s => new { s.UserId, s.CreatedAt });
    }
}

internal sealed class UserDocumentConfiguration : IEntityTypeConfiguration<UserDocument>
{
    public void Configure(EntityTypeBuilder<UserDocument> builder)
    {
        builder.ToTable("documents");
        builder.HasKey(d => d.Id);
        builder.Property(d => d.StorageKey).HasMaxLength(512);
        builder.Property(d => d.ContentType).HasMaxLength(64);
        builder.Property(d => d.ReviewNote).HasMaxLength(500);
        builder.Property(d => d.ReviewedBy).HasMaxLength(64);
        builder.HasOne<User>().WithMany().HasForeignKey(d => d.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasIndex(d => new { d.UserId, d.Type });

        // The admin review queue.
        builder.HasIndex(d => new { d.Status, d.UpdatedAt });
    }
}

internal sealed class VehicleConfiguration : IEntityTypeConfiguration<Vehicle>
{
    public void Configure(EntityTypeBuilder<Vehicle> builder)
    {
        builder.HasKey(v => v.Id);
        builder.Property(v => v.Make).HasMaxLength(50);
        builder.Property(v => v.Model).HasMaxLength(50);
        builder.Property(v => v.Color).HasMaxLength(30);
        builder.Property(v => v.PlateNumber).HasMaxLength(16);
        builder.HasOne<User>().WithMany().HasForeignKey(v => v.OwnerId).OnDelete(DeleteBehavior.Restrict);

        // A plate can only be registered once among active vehicles.
        builder.HasIndex(v => v.PlateNumber).IsUnique().HasFilter("is_archived = false");
    }
}

internal sealed class TripConfiguration : IEntityTypeConfiguration<Trip>
{
    public void Configure(EntityTypeBuilder<Trip> builder)
    {
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Notes).HasMaxLength(500);
        builder.Property(t => t.Version).IsRowVersion();
        builder.OwnsOne(t => t.Origin, ConfigureLocation);
        builder.OwnsOne(t => t.Destination, ConfigureLocation);
        builder.HasOne<User>().WithMany().HasForeignKey(t => t.DriverId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Vehicle>().WithMany().HasForeignKey(t => t.VehicleId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(t => new { t.Status, t.DepartureAt });
        builder.HasIndex(t => new { t.DriverId, t.DepartureAt });
    }

    private static void ConfigureLocation(OwnedNavigationBuilder<Trip, TripLocation> location)
    {
        location.Property(l => l.City).HasMaxLength(100);
        location.Property(l => l.Landmark).HasMaxLength(200);

        // geography: distances are computed on the sphere, in meters.
        location.Property(l => l.Point).HasColumnType("geography (point, 4326)");
        location.Ignore(l => l.Latitude);
        location.Ignore(l => l.Longitude);
        location.HasIndex(l => l.Point).HasMethod("gist");
        location.HasIndex(l => l.City);
    }
}

internal sealed class BookingConfiguration : IEntityTypeConfiguration<Booking>
{
    public void Configure(EntityTypeBuilder<Booking> builder)
    {
        builder.HasKey(b => b.Id);
        builder.Ignore(b => b.HoldsSeats);
        builder.HasOne<Trip>().WithMany().HasForeignKey(b => b.TripId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(b => b.PassengerId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(b => b.TripId);
        builder.HasIndex(b => new { b.PassengerId, b.CreatedAt });
    }
}

internal sealed class ReviewConfiguration : IEntityTypeConfiguration<Review>
{
    public void Configure(EntityTypeBuilder<Review> builder)
    {
        builder.HasKey(r => r.Id);
        builder.Property(r => r.Comment).HasMaxLength(Review.MaxCommentLength);
        builder.HasOne<Booking>().WithMany().HasForeignKey(r => r.BookingId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(r => r.AuthorId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(r => r.SubjectId).OnDelete(DeleteBehavior.Restrict);

        // One review per author per booking.
        builder.HasIndex(r => new { r.BookingId, r.AuthorId }).IsUnique();
        builder.HasIndex(r => r.SubjectId);
    }
}

internal sealed class DeviceTokenConfiguration : IEntityTypeConfiguration<DeviceToken>
{
    public void Configure(EntityTypeBuilder<DeviceToken> builder)
    {
        builder.HasKey(d => d.Id);
        builder.Property(d => d.Token).HasMaxLength(512);
        builder.HasIndex(d => d.Token).IsUnique();
        builder.HasIndex(d => d.UserId);
        builder.HasOne<User>().WithMany().HasForeignKey(d => d.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.Body).HasMaxLength(Message.MaxLength);
        builder.HasOne<Booking>().WithMany().HasForeignKey(m => m.BookingId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(m => m.SenderId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(m => m.RecipientId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(m => new { m.BookingId, m.SentAt });

        // Unread counters in the inbox.
        builder.HasIndex(m => new { m.RecipientId, m.ReadAt });
    }
}

internal sealed class TripPositionConfiguration : IEntityTypeConfiguration<TripPosition>
{
    public void Configure(EntityTypeBuilder<TripPosition> builder)
    {
        builder.HasKey(p => p.TripId);
        builder.Property(p => p.Point).HasColumnType("geography (point, 4326)");
        builder.Ignore(p => p.Latitude);
        builder.Ignore(p => p.Longitude);
        builder.HasOne<Trip>().WithOne().HasForeignKey<TripPosition>(p => p.TripId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class TripShareConfiguration : IEntityTypeConfiguration<TripShare>
{
    public void Configure(EntityTypeBuilder<TripShare> builder)
    {
        builder.HasKey(s => s.Token);
        builder.Property(s => s.Token).HasMaxLength(64);
        builder.HasOne<Trip>().WithMany().HasForeignKey(s => s.TripId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(s => s.CreatedById).OnDelete(DeleteBehavior.Cascade);
        builder.HasIndex(s => s.TripId);
    }
}
