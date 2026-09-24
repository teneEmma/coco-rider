using CocoRider.Api.Auth;
using CocoRider.Api.Features.Documents;
using CocoRider.Api.Features.Notifications;
using CocoRider.Api.Features.Trips;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Users;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CocoRider.Api.Features.Bookings;

public sealed record CreateBookingRequest(int Seats, PaymentMethod PaymentMethod);

/// <summary>A booking as the passenger sees it. The driver's phone is shown once the booking is confirmed.</summary>
public sealed record BookingResponse(Guid Id, BookingStatus Status, int Seats, PaymentMethod PaymentMethod,
    long TotalPriceXaf, TripResponse Trip, string? DriverPhone, DateTimeOffset CreatedAt);

public static class BookingEndpoints
{
    public static void MapBookingEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/v1/trips/{tripId:guid}/bookings", CreateAsync).WithTags("Bookings");
        app.MapGet("/v1/me/bookings", ListMineAsync).WithTags("Bookings");

        var bookings = app.MapGroup("/v1/bookings/{id:guid}").WithTags("Bookings");
        bookings.MapPost("/accept", AcceptAsync);
        bookings.MapPost("/reject", RejectAsync);
        bookings.MapPost("/cancel", CancelAsync);
        bookings.MapPost("/no-show", NoShowAsync);
    }

    private static async Task<IResult> CreateAsync(Guid tripId, CreateBookingRequest request, CurrentUser current,
        CocoRiderDbContext db, VerificationService verification, TripReader reader, IOptions<PlatformPolicy> policy,
        Notifier notifier, TimeProvider clock, CancellationToken ct)
    {
        var booking = await Concurrency.RetryAsync(db, async () =>
        {
            var passenger = await current.RequireProfileAsync(ct);
            var trip = await TripEndpoints.FindTripAsync(db, tripId, ct);

            var alreadyBooked = await db.Bookings.AnyAsync(b => b.TripId == tripId && b.PassengerId == passenger.Id
                && (b.Status == BookingStatus.Pending || b.Status == BookingStatus.Confirmed), ct);
            if (alreadyBooked)
                throw new DomainException("booking.already_booked", "You already have a booking on this trip.");

            await verification.RefreshAsync(passenger, ct);
            var created = Booking.Request(trip, passenger, request.Seats, request.PaymentMethod, clock.GetUtcNow(), policy.Value);
            db.Bookings.Add(created);
            await db.SaveChangesAsync(ct);
            notifier.BookingCreated(created, trip, passenger);
            return created;
        });

        return Results.Created($"/v1/bookings/{booking.Id}", await ToResponseAsync(db, reader, booking, ct));
    }

    private static async Task<IEnumerable<BookingResponse>> ListMineAsync(CurrentUser current, CocoRiderDbContext db,
        TripReader reader, CancellationToken ct)
    {
        var passenger = await current.RequireProfileAsync(ct);
        var bookings = await db.Bookings.Where(b => b.PassengerId == passenger.Id)
            .OrderByDescending(b => b.CreatedAt).Take(100).ToListAsync(ct);

        var responses = new List<BookingResponse>(bookings.Count);
        foreach (var booking in bookings)
            responses.Add(await ToResponseAsync(db, reader, booking, ct));
        return responses;
    }

    private static Task<BookingResponse> AcceptAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        Notifier notifier, TimeProvider clock, CancellationToken ct) =>
        ChangeAsync(id, current, db, reader, ct,
            (booking, trip, user) => booking.Accept(trip, user.Id, clock.GetUtcNow()),
            (booking, trip, _) => notifier.BookingAnswered(booking, trip));

    private static Task<BookingResponse> RejectAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        Notifier notifier, TimeProvider clock, CancellationToken ct) =>
        ChangeAsync(id, current, db, reader, ct,
            (booking, trip, user) => booking.Reject(trip, user.Id, clock.GetUtcNow()),
            (booking, trip, _) => notifier.BookingAnswered(booking, trip));

    private static Task<BookingResponse> CancelAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        IOptions<PlatformPolicy> policy, Notifier notifier, TimeProvider clock, CancellationToken ct) =>
        ChangeAsync(id, current, db, reader, ct,
            (booking, trip, user) => booking.CancelByPassenger(trip, user.Id, clock.GetUtcNow(), policy.Value),
            notifier.BookingCancelledByPassenger);

    /// <summary>The driver reports a no-show after departure; the passenger gets a strike.</summary>
    private static Task<BookingResponse> NoShowAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        IOptions<PlatformPolicy> policy, TimeProvider clock, CancellationToken ct) =>
        ChangeAsync(id, current, db, reader, ct, async (booking, trip, user) =>
        {
            var now = clock.GetUtcNow();
            booking.MarkNoShow(trip, user.Id, now);
            var passenger = await db.Users.Include(u => u.Strikes).FirstAsync(u => u.Id == booking.PassengerId, ct);
            passenger.AddStrike(StrikeReason.PassengerNoShow, booking.Id, now, policy.Value);
        });

    private static Task<BookingResponse> ChangeAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        CancellationToken ct, Action<Booking, Domain.Trips.Trip, User> change, Action<Booking, Domain.Trips.Trip, User>? afterSave = null) =>
        ChangeAsync(id, current, db, reader, ct, (booking, trip, user) =>
        {
            change(booking, trip, user);
            return Task.CompletedTask;
        }, afterSave);

    /// <param name="afterSave">Runs once the change is saved (e.g. to notify the other party).</param>
    private static Task<BookingResponse> ChangeAsync(Guid id, CurrentUser current, CocoRiderDbContext db, TripReader reader,
        CancellationToken ct, Func<Booking, Domain.Trips.Trip, User, Task> change, Action<Booking, Domain.Trips.Trip, User>? afterSave = null) =>
        Concurrency.RetryAsync(db, async () =>
        {
            var user = await current.RequireProfileAsync(ct);
            var booking = await db.Bookings.FirstOrDefaultAsync(b => b.Id == id, ct)
                ?? throw new NotFoundException("booking.not_found", "Booking not found.");
            var trip = await TripEndpoints.FindTripAsync(db, booking.TripId, ct);

            if (user.Id != booking.PassengerId && user.Id != trip.DriverId)
                throw new NotFoundException("booking.not_found", "Booking not found.");

            await change(booking, trip, user);
            await db.SaveChangesAsync(ct);
            afterSave?.Invoke(booking, trip, user);
            return await ToResponseAsync(db, reader, booking, ct);
        });

    private static async Task<BookingResponse> ToResponseAsync(CocoRiderDbContext db, TripReader reader, Booking booking, CancellationToken ct)
    {
        var trip = await TripEndpoints.FindTripAsync(db, booking.TripId, ct);
        string? driverPhone = null;
        if (booking.Status is BookingStatus.Confirmed or BookingStatus.Completed)
            driverPhone = await db.Users.Where(u => u.Id == trip.DriverId).Select(u => u.PhoneNumber).FirstAsync(ct);

        return new BookingResponse(booking.Id, booking.Status, booking.Seats, booking.PaymentMethod, booking.TotalPriceXaf,
            await reader.ToResponseAsync(trip, ct), driverPhone, booking.CreatedAt);
    }
}
