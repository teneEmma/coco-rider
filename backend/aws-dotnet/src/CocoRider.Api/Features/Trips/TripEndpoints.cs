using CocoRider.Api.Auth;
using CocoRider.Api.Features.Documents;
using CocoRider.Api.Features.Notifications;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CocoRider.Api.Features.Trips;

public static class TripEndpoints
{
    /// <summary>Cameroon is on West Africa Time (UTC+1) all year, without daylight saving.</summary>
    public static readonly TimeSpan CameroonOffset = TimeSpan.FromHours(1);

    private const int MaxSearchResults = 50;
    private const double DefaultRadiusKm = 5;
    private const double MaxRadiusKm = 50;

    public static void MapTripEndpoints(this IEndpointRouteBuilder app)
    {
        var trips = app.MapGroup("/v1/trips").WithTags("Trips");
        trips.MapPost("/", PublishAsync);
        trips.MapGet("/search", SearchAsync);
        trips.MapGet("/{id:guid}", GetAsync);
        trips.MapPost("/{id:guid}/cancel", CancelAsync);
        trips.MapPost("/{id:guid}/complete", CompleteAsync);

        app.MapGet("/v1/me/trips", ListMineAsync).WithTags("Trips");
    }

    private static async Task<IResult> PublishAsync(PublishTripRequest request, CurrentUser current, CocoRiderDbContext db,
        VerificationService verification, TripReader reader, IOptions<PlatformPolicy> policy, TimeProvider clock, CancellationToken ct)
    {
        var driver = await current.RequireProfileAsync(ct);
        var vehicle = await db.Vehicles.FirstOrDefaultAsync(v => v.Id == request.VehicleId, ct)
            ?? throw new NotFoundException("vehicle.not_found", "Vehicle not found.");

        await verification.RefreshAsync(driver, ct);

        var trip = Trip.Publish(driver, vehicle, request.Kind, request.Origin.ToDomain(), request.Destination.ToDomain(),
            request.DepartureAt, request.Seats, request.PricePerSeatXaf,
            new TripPreferences(request.WomenOnly, request.LuggageAllowed, request.SmokingAllowed, request.InstantBooking),
            request.Notes, clock.GetUtcNow(), policy.Value);

        db.Trips.Add(trip);
        await db.SaveChangesAsync(ct);
        return Results.Created($"/v1/trips/{trip.Id}", await reader.ToResponseAsync(trip, ct));
    }

    /// <summary>
    /// Finds scheduled trips on a given day. Either coordinates (with a radius, for city commutes)
    /// or city names (for intercity trips) can be used for each end.
    /// </summary>
    private static async Task<IEnumerable<TripResponse>> SearchAsync(
        DateOnly date,
        double? fromLat, double? fromLng, double? toLat, double? toLng, double? radiusKm,
        string? fromCity, string? toCity, int? seats, TripKind? kind,
        CurrentUser current, CocoRiderDbContext db, TripReader reader, TimeProvider clock, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var dayStart = new DateTimeOffset(date.ToDateTime(TimeOnly.MinValue), CameroonOffset).ToUniversalTime();
        var dayEnd = dayStart.AddDays(1);
        var minSeats = Math.Max(1, seats ?? 1);
        var radiusMeters = Math.Clamp(radiusKm ?? DefaultRadiusKm, 0.1, MaxRadiusKm) * 1000;

        var query = db.Trips.Where(t => t.Status == TripStatus.Scheduled
            && t.DepartureAt >= dayStart && t.DepartureAt < dayEnd && t.DepartureAt > now
            && t.SeatsAvailable >= minSeats);

        if (kind is { } k)
            query = query.Where(t => t.Kind == k);

        if (fromLat is { } fLat && fromLng is { } fLng)
        {
            var from = TripLocation.CreatePoint(fLat, fLng);
            query = query.Where(t => t.Origin.Point.IsWithinDistance(from, radiusMeters));
        }
        else if (!string.IsNullOrWhiteSpace(fromCity))
        {
            var city = fromCity.Trim().ToLower();
            query = query.Where(t => t.Origin.City.ToLower() == city);
        }

        if (toLat is { } tLat && toLng is { } tLng)
        {
            var to = TripLocation.CreatePoint(tLat, tLng);
            query = query.Where(t => t.Destination.Point.IsWithinDistance(to, radiusMeters));
        }
        else if (!string.IsNullOrWhiteSpace(toCity))
        {
            var city = toCity.Trim().ToLower();
            query = query.Where(t => t.Destination.City.ToLower() == city);
        }

        // Women-only trips are only shown to women.
        var caller = await current.FindProfileAsync(ct);
        if (caller?.Gender != Gender.Female)
            query = query.Where(t => !t.WomenOnly);

        var trips = await query.OrderBy(t => t.DepartureAt).Take(MaxSearchResults).ToListAsync(ct);
        return await reader.ToResponsesAsync(trips, ct);
    }

    private static async Task<TripDetailsResponse> GetAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader, CancellationToken ct)
    {
        var trip = await db.Trips.FirstOrDefaultAsync(t => t.Id == id, ct)
            ?? throw new NotFoundException("trip.not_found", "Trip not found.");
        var caller = await current.FindProfileAsync(ct);

        IReadOnlyList<TripBookingResponse>? bookings = null;
        if (caller?.Id == trip.DriverId)
        {
            bookings = await db.Bookings.Where(b => b.TripId == trip.Id)
                .Join(db.Users, b => b.PassengerId, u => u.Id, (b, u) => new { b, u })
                .OrderBy(x => x.b.CreatedAt)
                .Select(x => new TripBookingResponse(x.b.Id, x.u.Id, x.u.FirstName,
                    x.b.Status == BookingStatus.Confirmed || x.b.Status == BookingStatus.Completed ? x.u.PhoneNumber : null,
                    x.b.Seats, x.b.Status, x.b.PaymentMethod, x.b.TotalPriceXaf))
                .ToListAsync(ct);
        }

        return new TripDetailsResponse(await reader.ToResponseAsync(trip, ct), bookings);
    }

    private static async Task<IEnumerable<TripResponse>> ListMineAsync(bool? past, CurrentUser current, CocoRiderDbContext db,
        TripReader reader, TimeProvider clock, CancellationToken ct)
    {
        var driver = await current.RequireProfileAsync(ct);
        var now = clock.GetUtcNow();
        var query = db.Trips.Where(t => t.DriverId == driver.Id);
        query = past == true
            ? query.Where(t => t.DepartureAt <= now).OrderByDescending(t => t.DepartureAt)
            : query.Where(t => t.DepartureAt > now).OrderBy(t => t.DepartureAt);

        return await reader.ToResponsesAsync(await query.Take(100).ToListAsync(ct), ct);
    }

    /// <summary>
    /// The driver cancels: every booking is cancelled. A late cancellation (inside the window)
    /// that affects passengers costs the driver a strike.
    /// </summary>
    private static Task<TripResponse> CancelAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        IOptions<PlatformPolicy> policy, Notifier notifier, TimeProvider clock, CancellationToken ct) =>
        Concurrency.RetryAsync(db, async () =>
        {
            var driver = await current.RequireProfileAsync(ct);
            var trip = await FindTripAsync(db, id, ct);
            var now = clock.GetUtcNow();

            var late = trip.Cancel(driver.Id, now, policy.Value);
            var bookings = await db.Bookings.Where(b => b.TripId == trip.Id).ToListAsync(ct);
            var affected = bookings.Where(b => b.HoldsSeats).ToList();
            affected.ForEach(b => b.CancelBecauseTripCancelled(now));

            if (late && affected.Count > 0)
                driver.AddStrike(StrikeReason.DriverLateCancellation, null, now, policy.Value);

            await db.SaveChangesAsync(ct);
            notifier.TripOutcome(trip, affected);
            return await reader.ToResponseAsync(trip, ct);
        });

    private static async Task<TripResponse> CompleteAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        Notifier notifier, TimeProvider clock, CancellationToken ct)
    {
        var driver = await current.RequireProfileAsync(ct);
        var trip = await FindTripAsync(db, id, ct);
        var now = clock.GetUtcNow();

        trip.Complete(driver.Id, now);
        var affected = await db.Bookings
            .Where(b => b.TripId == trip.Id && (b.Status == BookingStatus.Pending || b.Status == BookingStatus.Confirmed))
            .ToListAsync(ct);
        affected.ForEach(b => b.CompleteWithTrip(now));

        await db.SaveChangesAsync(ct);
        notifier.TripOutcome(trip, affected);
        return await reader.ToResponseAsync(trip, ct);
    }

    internal static async Task<Trip> FindTripAsync(CocoRiderDbContext db, Guid id, CancellationToken ct) =>
        await db.Trips.FirstOrDefaultAsync(t => t.Id == id, ct)
            ?? throw new NotFoundException("trip.not_found", "Trip not found.");
}
