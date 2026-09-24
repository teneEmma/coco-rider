using CocoRider.Api.Auth;
using CocoRider.Domain.Common;
using CocoRider.Domain.Vehicles;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Vehicles;

public sealed record CreateVehicleRequest(string Make, string Model, string Color, string PlateNumber, int PassengerSeats);

public sealed record VehicleResponse(Guid Id, string Make, string Model, string Color, string PlateNumber, int PassengerSeats)
{
    public static VehicleResponse From(Vehicle v) => new(v.Id, v.Make, v.Model, v.Color, v.PlateNumber, v.PassengerSeats);
}

public static class VehicleEndpoints
{
    public static void MapVehicleEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/me/vehicles").WithTags("Vehicles");
        group.MapGet("/", ListAsync);
        group.MapPost("/", CreateAsync);
        group.MapDelete("/{id:guid}", ArchiveAsync);
    }

    private static async Task<IEnumerable<VehicleResponse>> ListAsync(CurrentUser current, CocoRiderDbContext db, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        var vehicles = await db.Vehicles.Where(v => v.OwnerId == user.Id && !v.IsArchived).ToListAsync(ct);
        return vehicles.Select(VehicleResponse.From);
    }

    private static async Task<IResult> CreateAsync(CreateVehicleRequest request, CurrentUser current, CocoRiderDbContext db, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        var vehicle = new Vehicle(user.Id, request.Make, request.Model, request.Color, request.PlateNumber, request.PassengerSeats);

        if (await db.Vehicles.AnyAsync(v => v.PlateNumber == vehicle.PlateNumber && !v.IsArchived, ct))
            throw new DomainException("vehicle.plate_taken", "This plate number is already registered.");

        db.Vehicles.Add(vehicle);
        await db.SaveChangesAsync(ct);
        return Results.Created($"/v1/me/vehicles/{vehicle.Id}", VehicleResponse.From(vehicle));
    }

    private static async Task<IResult> ArchiveAsync(Guid id, CurrentUser current, CocoRiderDbContext db, CancellationToken ct)
    {
        var user = await current.RequireProfileAsync(ct);
        var vehicle = await db.Vehicles.FirstOrDefaultAsync(v => v.Id == id && v.OwnerId == user.Id, ct)
            ?? throw new NotFoundException("vehicle.not_found", "Vehicle not found.");

        // Archived rather than deleted: past trips keep pointing to it.
        vehicle.Archive();
        await db.SaveChangesAsync(ct);
        return Results.NoContent();
    }
}
