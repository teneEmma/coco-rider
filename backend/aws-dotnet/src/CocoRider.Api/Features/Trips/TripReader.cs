using CocoRider.Domain.Trips;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Trips;

public sealed record Rating(double Average, int Count);

/// <summary>Builds trip responses with the driver, vehicle and rating, in a fixed number of queries.</summary>
public sealed class TripReader(CocoRiderDbContext db)
{
    public async Task<List<TripResponse>> ToResponsesAsync(IReadOnlyCollection<Trip> trips, CancellationToken ct)
    {
        var driverIds = trips.Select(t => t.DriverId).Distinct().ToList();
        var vehicleIds = trips.Select(t => t.VehicleId).Distinct().ToList();

        var drivers = await db.Users.Where(u => driverIds.Contains(u.Id))
            .Select(u => new { u.Id, u.FirstName })
            .ToDictionaryAsync(u => u.Id, u => u.FirstName, ct);
        var vehicles = await db.Vehicles.Where(v => vehicleIds.Contains(v.Id))
            .ToDictionaryAsync(v => v.Id, ct);
        var ratings = await RatingsAsync(driverIds, ct);

        return trips.Select(t =>
        {
            var rating = ratings.GetValueOrDefault(t.DriverId);
            var vehicle = vehicles[t.VehicleId];
            return new TripResponse(t.Id, t.Kind, t.Status, LocationDto.From(t.Origin), LocationDto.From(t.Destination),
                t.DepartureAt, t.SeatsTotal, t.SeatsAvailable, t.PricePerSeatXaf, t.LuggageAllowed,
                t.SmokingAllowed, t.InstantBooking, t.Notes,
                new DriverSummary(t.DriverId, drivers[t.DriverId], rating?.Average, rating?.Count ?? 0),
                new VehicleSummary(vehicle.Make, vehicle.Model, vehicle.Color));
        }).ToList();
    }

    public async Task<TripResponse> ToResponseAsync(Trip trip, CancellationToken ct) =>
        (await ToResponsesAsync([trip], ct))[0];

    public async Task<Dictionary<Guid, Rating>> RatingsAsync(IReadOnlyCollection<Guid> userIds, CancellationToken ct) =>
        await db.Reviews.Where(r => userIds.Contains(r.SubjectId))
            .GroupBy(r => r.SubjectId)
            .Select(g => new { g.Key, Average = g.Average(r => (double)r.Rating), Count = g.Count() })
            .ToDictionaryAsync(g => g.Key, g => new Rating(Math.Round(g.Average, 1), g.Count), ct);
}
