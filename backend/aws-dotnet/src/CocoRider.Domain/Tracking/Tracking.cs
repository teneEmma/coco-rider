using System.Security.Cryptography;
using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;
using NetTopologySuite.Geometries;

namespace CocoRider.Domain.Tracking;

/// <summary>
/// The latest known position of a trip's driver. Only the last position is kept (no history),
/// and it is deleted when the trip ends.
/// </summary>
public sealed class TripPosition
{
    /// <summary>After this delay without update, the position is shown as "last seen at" rather than live.</summary>
    public static readonly TimeSpan LiveFor = TimeSpan.FromMinutes(2);

    /// <summary>Sharing can start this long before departure (the driver drives to the pick-up point).</summary>
    public static readonly TimeSpan StartsBeforeDeparture = TimeSpan.FromHours(1);

    private TripPosition() { }

    public Guid TripId { get; private set; }
    public Point Point { get; private set; } = null!;
    public double? HeadingDegrees { get; private set; }
    public double? SpeedKmh { get; private set; }

    /// <summary>When the phone measured the position.</summary>
    public DateTimeOffset RecordedAt { get; private set; }

    /// <summary>When the driver started sharing (first position of the trip).</summary>
    public DateTimeOffset StartedAt { get; private set; }

    public double Latitude => Point.Y;
    public double Longitude => Point.X;

    public bool IsLive(DateTimeOffset now) => now - RecordedAt <= LiveFor;

    /// <summary>
    /// Records a position sent by the driver. Returns the new row for the first position of the
    /// trip (the caller notifies the passengers), otherwise updates <paramref name="current"/>.
    /// </summary>
    public static TripPosition? Record(TripPosition? current, Trip trip, Guid driverId, double latitude, double longitude,
        double? headingDegrees, double? speedKmh, DateTimeOffset recordedAt, DateTimeOffset now, PlatformPolicy policy)
    {
        trip.EnsureDriver(driverId);
        if (trip.Status != TripStatus.Scheduled || now < trip.DepartureAt - StartsBeforeDeparture
            || now > trip.DepartureAt.AddHours(policy.AutoCompleteAfterHours))
            throw new DomainException("tracking.not_active", "Position sharing is only possible around the trip's departure.");
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180)
            throw new DomainException("location.invalid_coordinates", "The coordinates are invalid.");

        // Phone clocks drift: never store a time in the future.
        var measuredAt = recordedAt > now ? now : recordedAt.ToUniversalTime();
        var point = TripLocation.CreatePoint(latitude, longitude);
        var heading = headingDegrees is >= 0 and < 360 ? headingDegrees : null;
        var speed = speedKmh is >= 0 and < 250 ? speedKmh : null;

        if (current is null)
        {
            return new TripPosition
            {
                TripId = trip.Id,
                Point = point,
                HeadingDegrees = heading,
                SpeedKmh = speed,
                RecordedAt = measuredAt,
                StartedAt = now,
            };
        }

        // Positions can arrive out of order on a bad network: keep the most recent one.
        if (measuredAt >= current.RecordedAt)
        {
            current.Point = point;
            current.HeadingDegrees = heading;
            current.SpeedKmh = speed;
            current.RecordedAt = measuredAt;
        }
        return null;
    }
}

/// <summary>A link a passenger sends to relatives so they can follow the trip without the app.</summary>
public sealed class TripShare
{
    private TripShare() { }

    /// <summary>Unguessable URL-safe token (256 bits).</summary>
    public string Token { get; private set; } = null!;
    public Guid TripId { get; private set; }
    public Guid CreatedById { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset ExpiresAt { get; private set; }

    public bool IsValid(DateTimeOffset now) => now < ExpiresAt;

    public static TripShare Create(Trip trip, Guid userId, DateTimeOffset now) => new()
    {
        Token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_'),
        TripId = trip.Id,
        CreatedById = userId,
        CreatedAt = now,
        ExpiresAt = trip.DepartureAt.AddHours(24),
    };
}

public static class Geo
{
    private const double EarthRadiusKm = 6371;

    /// <summary>Great-circle ("as the crow flies") distance between two points, in kilometres.</summary>
    public static double DistanceKm(double lat1, double lon1, double lat2, double lon2)
    {
        static double Rad(double degrees) => degrees * Math.PI / 180;
        var dLat = Rad(lat2 - lat1);
        var dLon = Rad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
            + Math.Cos(Rad(lat1)) * Math.Cos(Rad(lat2)) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return 2 * EarthRadiusKm * Math.Asin(Math.Sqrt(a));
    }
}
