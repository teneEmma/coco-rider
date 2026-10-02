using CocoRider.Api.Auth;
using CocoRider.Api.Features.Notifications;
using CocoRider.Api.Features.Trips;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Tracking;
using CocoRider.Domain.Trips;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CocoRider.Api.Features.Tracking;

public sealed class TrackingOptions
{
    /// <summary>Public website (landing page) that shows shared trips at /suivi/{token}.</summary>
    public string PublicBaseUrl { get; set; } = "http://localhost:5173";
}

public sealed record UpdatePositionRequest(double Latitude, double Longitude, double? Heading, double? SpeedKmh, DateTimeOffset RecordedAt);

public sealed record PositionResponse(double Latitude, double Longitude, double? Heading, double? SpeedKmh,
    DateTimeOffset RecordedAt, bool IsLive, double DistanceToDestinationKm);

/// <summary>What the passengers see. <see cref="Position"/> is null until the driver starts sharing.</summary>
public sealed record TrackingResponse(Guid TripId, TripStatus TripStatus, LocationDto Destination, PositionResponse? Position);

public sealed record ShareResponse(string Token, Uri Url, DateTimeOffset ExpiresAt);

public sealed record SharedVehicle(string Make, string Model, string Color, string PlateNumber);

/// <summary>Public view of a shared trip: enough for relatives to recognise the car, nothing more.</summary>
public sealed record SharedTripResponse(LocationDto Origin, LocationDto Destination, DateTimeOffset DepartureAt, TripStatus Status,
    string DriverFirstName, SharedVehicle Vehicle, PositionResponse? Position, DateTimeOffset ExpiresAt);

public static class TrackingEndpoints
{
    public static void MapTrackingEndpoints(this IEndpointRouteBuilder app)
    {
        var trip = app.MapGroup("/v1/trips/{id:guid}").WithTags("Tracking");
        trip.MapPut("/position", UpdateAsync);
        trip.MapDelete("/position", StopAsync);
        trip.MapGet("/position", GetAsync);
        trip.MapPost("/shares", ShareAsync);

        app.MapGet("/v1/shared/{token}", GetSharedAsync).WithTags("Tracking").AllowAnonymous();
    }

    /// <summary>Called by the driver's phone every few seconds while sharing.</summary>
    private static async Task<IResult> UpdateAsync(Guid id, UpdatePositionRequest request, CurrentUser current, CocoRiderDbContext db,
        Notifier notifier, IOptions<PlatformPolicy> policy, TimeProvider clock, CancellationToken ct)
    {
        var driver = await current.RequireProfileAsync(ct);
        var trip = await TripEndpoints.FindTripAsync(db, id, ct);
        var existing = await db.TripPositions.FirstOrDefaultAsync(p => p.TripId == id, ct);

        var created = TripPosition.Record(existing, trip, driver.Id, request.Latitude, request.Longitude,
            request.Heading, request.SpeedKmh, request.RecordedAt, clock.GetUtcNow(), policy.Value);
        if (created is not null)
            db.TripPositions.Add(created);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException) when (created is not null)
        {
            // Two first positions raced; the other one was stored and already notified the passengers.
            return Results.NoContent();
        }

        if (created is not null)
            notifier.TripStarted(trip, driver, await ConfirmedPassengersAsync(db, trip.Id, ct));

        return Results.NoContent();
    }

    private static async Task<IResult> StopAsync(Guid id, CurrentUser current, CocoRiderDbContext db, CancellationToken ct)
    {
        var driver = await current.RequireProfileAsync(ct);
        var trip = await TripEndpoints.FindTripAsync(db, id, ct);
        trip.EnsureDriver(driver.Id);
        await db.TripPositions.Where(p => p.TripId == id).ExecuteDeleteAsync(ct);
        return Results.NoContent();
    }

    private static async Task<TrackingResponse> GetAsync(Guid id, CurrentUser current, CocoRiderDbContext db,
        TimeProvider clock, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        var trip = await TripEndpoints.FindTripAsync(db, id, ct);
        await EnsureCanFollowAsync(db, trip, user.Id, ct);

        return new TrackingResponse(trip.Id, trip.Status, LocationDto.From(trip.Destination),
            await PositionAsync(db, trip, clock.GetUtcNow(), ct));
    }

    /// <summary>Creates a link to follow the trip without the app (e.g. sent by WhatsApp to relatives).</summary>
    private static async Task<IResult> ShareAsync(Guid id, CurrentUser current, CocoRiderDbContext db,
        IOptions<TrackingOptions> options, TimeProvider clock, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        var trip = await TripEndpoints.FindTripAsync(db, id, ct);
        await EnsureCanFollowAsync(db, trip, user.Id, ct);
        if (trip.Status != TripStatus.Scheduled)
            throw new DomainException("tracking.trip_over", "This trip is over.");

        var share = TripShare.Create(trip, user.Id, clock.GetUtcNow());
        db.TripShares.Add(share);
        await db.SaveChangesAsync(ct);

        var url = new Uri($"{options.Value.PublicBaseUrl.TrimEnd('/')}/suivi/{share.Token}");
        return Results.Created(url, new ShareResponse(share.Token, url, share.ExpiresAt));
    }

    private static async Task<SharedTripResponse> GetSharedAsync(string token, CocoRiderDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var share = await db.TripShares.FirstOrDefaultAsync(s => s.Token == token, ct);
        if (share is null || !share.IsValid(now))
            throw new NotFoundException("tracking.share_not_found", "This link has expired.");

        var trip = await TripEndpoints.FindTripAsync(db, share.TripId, ct);
        var driverName = await db.Users.Where(u => u.Id == trip.DriverId).Select(u => u.FirstName).FirstAsync(ct);
        var vehicle = await db.Vehicles.Where(v => v.Id == trip.VehicleId)
            .Select(v => new SharedVehicle(v.Make, v.Model, v.Color, v.PlateNumber)).FirstAsync(ct);

        return new SharedTripResponse(LocationDto.From(trip.Origin), LocationDto.From(trip.Destination), trip.DepartureAt,
            trip.Status, driverName, vehicle, await PositionAsync(db, trip, now, ct), share.ExpiresAt);
    }

    /// <summary>The driver and passengers with a confirmed (or completed) booking.</summary>
    private static async Task EnsureCanFollowAsync(CocoRiderDbContext db, Trip trip, Guid userId, CancellationToken ct)
    {
        if (userId == trip.DriverId)
            return;
        var confirmed = await db.Bookings.AnyAsync(b => b.TripId == trip.Id && b.PassengerId == userId
            && (b.Status == BookingStatus.Confirmed || b.Status == BookingStatus.Completed), ct);
        if (!confirmed)
            throw new NotFoundException("trip.not_found", "Trip not found.");
    }

    /// <summary>The position is only shown while the trip is running; it is deleted afterwards.</summary>
    private static async Task<PositionResponse?> PositionAsync(CocoRiderDbContext db, Trip trip, DateTimeOffset now, CancellationToken ct)
    {
        if (trip.Status != TripStatus.Scheduled)
            return null;
        var position = await db.TripPositions.FirstOrDefaultAsync(p => p.TripId == trip.Id, ct);
        if (position is null)
            return null;

        var distance = Geo.DistanceKm(position.Latitude, position.Longitude, trip.Destination.Latitude, trip.Destination.Longitude);
        return new PositionResponse(position.Latitude, position.Longitude, position.HeadingDegrees, position.SpeedKmh,
            position.RecordedAt, position.IsLive(now), Math.Round(distance, 1));
    }

    private static Task<List<Guid>> ConfirmedPassengersAsync(CocoRiderDbContext db, Guid tripId, CancellationToken ct) =>
        db.Bookings.Where(b => b.TripId == tripId && b.Status == BookingStatus.Confirmed)
            .Select(b => b.PassengerId).Distinct().ToListAsync(ct);
}
