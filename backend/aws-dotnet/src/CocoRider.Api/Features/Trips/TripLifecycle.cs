using CocoRider.Api.Features.Notifications;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CocoRider.Api.Features.Trips;

public sealed class LifecycleOptions
{
    /// <summary>Turned off in tests, which run <see cref="TripLifecycle"/> by hand.</summary>
    public bool Enabled { get; set; } = true;

    public int IntervalMinutes { get; set; } = 5;
}

public sealed record LifecycleResult(int ExpiredRequests, int CompletedTrips);

/// <summary>
/// Housekeeping after departure: requests the driver never answered expire, and trips the driver
/// forgot to complete are closed so that passengers can leave a review. Safe to run repeatedly.
/// </summary>
public sealed class TripLifecycle(
    CocoRiderDbContext db,
    IOptions<PlatformPolicy> policy,
    TimeProvider clock,
    Notifier notifier,
    ILogger<TripLifecycle> logger)
{
    private const int BatchSize = 200;

    public async Task<LifecycleResult> RunAsync(CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var completeBefore = now.AddHours(-policy.Value.AutoCompleteAfterHours);

        var tripIds = await db.Trips
            .Where(t => t.Status == TripStatus.Scheduled && t.DepartureAt <= now
                && (t.DepartureAt <= completeBefore
                    || db.Bookings.Any(b => b.TripId == t.Id && b.Status == BookingStatus.Pending)))
            .OrderBy(t => t.DepartureAt)
            .Select(t => t.Id)
            .Take(BatchSize)
            .ToListAsync(ct);

        var expired = 0;
        var completed = 0;
        foreach (var tripId in tripIds)
        {
            try
            {
                var (e, c) = await ProcessTripAsync(tripId, now, ct);
                expired += e;
                completed += c;
            }
            catch (DbUpdateConcurrencyException)
            {
                // Someone (e.g. the driver) changed the trip meanwhile; the next run picks it up again.
                db.ChangeTracker.Clear();
            }
        }

        if (expired > 0 || completed > 0)
            logger.LogInformation("Trip lifecycle: {Expired} requests expired, {Completed} trips completed", expired, completed);

        return new LifecycleResult(expired, completed);
    }

    private async Task<(int Expired, int Completed)> ProcessTripAsync(Guid tripId, DateTimeOffset now, CancellationToken ct)
    {
        var trip = await db.Trips.FirstAsync(t => t.Id == tripId, ct);
        var bookings = await db.Bookings.Where(b => b.TripId == tripId).ToListAsync(ct);

        var expired = bookings.Where(b => b.Status == BookingStatus.Pending).ToList();
        expired.ForEach(b => b.ExpireIfUnanswered(trip, now));

        var completed = trip.AutoComplete(now, policy.Value);
        var finished = completed ? bookings.Where(b => b.HoldsSeats).ToList() : [];
        finished.ForEach(b => b.CompleteWithTrip(now));

        await db.SaveChangesAsync(ct);
        db.ChangeTracker.Clear();
        notifier.TripOutcome(trip, [.. expired, .. finished]);
        return (expired.Count, completed ? 1 : 0);
    }
}

/// <summary>Runs <see cref="TripLifecycle"/> every few minutes inside the API container.</summary>
public sealed class TripLifecycleService(
    IServiceScopeFactory scopes,
    IOptions<LifecycleOptions> options,
    ILogger<TripLifecycleService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled)
            return;

        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(options.Value.IntervalMinutes));
        do
        {
            try
            {
                using var scope = scopes.CreateScope();
                await scope.ServiceProvider.GetRequiredService<TripLifecycle>().RunAsync(stoppingToken);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                logger.LogError(e, "Trip lifecycle run failed");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
