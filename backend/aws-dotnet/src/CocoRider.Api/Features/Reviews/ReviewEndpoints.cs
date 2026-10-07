using CocoRider.Api.Auth;
using CocoRider.Api.Features.Trips;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Reviews;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Reviews;

public sealed record CreateReviewRequest(int Rating, string? Comment);

public sealed record ReviewResponse(Guid Id, string AuthorFirstName, int Rating, string? Comment, DateTimeOffset CreatedAt);

/// <summary>What anyone can see about another user. Never includes the phone number.</summary>
public sealed record PublicProfileResponse(Guid Id, string FirstName, string LastInitial, double? Rating, int ReviewCount,
    int TripsAsDriver, bool VerifiedDriver, bool VerifiedPassenger, DateTimeOffset MemberSince);

public static class ReviewEndpoints
{
    public static void MapReviewEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/v1/bookings/{id:guid}/reviews", CreateAsync).WithTags("Reviews");

        var users = app.MapGroup("/v1/users/{id:guid}").WithTags("Reviews");
        users.MapGet("/", GetPublicProfileAsync);
        users.MapGet("/reviews", ListAsync);
    }

    private static async Task<IResult> CreateAsync(Guid id, CreateReviewRequest request, CurrentUser current,
        CocoRiderDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var author = await current.RequireProfileAsync(ct);
        var booking = await db.Bookings.FirstOrDefaultAsync(b => b.Id == id, ct)
            ?? throw new NotFoundException("booking.not_found", "Booking not found.");
        var trip = await TripEndpoints.FindTripAsync(db, booking.TripId, ct);

        if (await db.Reviews.AnyAsync(r => r.BookingId == id && r.AuthorId == author.Id, ct))
            throw new DomainException("review.already_written", "You already reviewed this trip.");

        var review = Review.Write(booking, trip, author.Id, request.Rating, request.Comment, clock.GetUtcNow());
        db.Reviews.Add(review);
        await db.SaveChangesAsync(ct);
        return Results.Created($"/v1/users/{review.SubjectId}/reviews",
            new ReviewResponse(review.Id, author.FirstName, review.Rating, review.Comment, review.CreatedAt));
    }

    private static async Task<IEnumerable<ReviewResponse>> ListAsync(Guid id, CocoRiderDbContext db, CancellationToken ct) =>
        await db.Reviews.Where(r => r.SubjectId == id)
            .Join(db.Users, r => r.AuthorId, u => u.Id, (r, u) => new { r, u.FirstName })
            .OrderByDescending(x => x.r.CreatedAt)
            .Take(50)
            .Select(x => new ReviewResponse(x.r.Id, x.FirstName, x.r.Rating, x.r.Comment, x.r.CreatedAt))
            .ToListAsync(ct);

    private static async Task<PublicProfileResponse> GetPublicProfileAsync(Guid id, CocoRiderDbContext db, TripReader reader, CancellationToken ct)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == id, ct)
            ?? throw new NotFoundException("user.not_found", "User not found.");
        var rating = (await reader.RatingsAsync([id], ct)).GetValueOrDefault(id);
        var trips = await db.Trips.CountAsync(t => t.DriverId == id && t.Status == TripStatus.Completed, ct);

        return new PublicProfileResponse(user.Id, user.FirstName, user.LastName[..1] + ".", rating?.Average, rating?.Count ?? 0,
            trips, user.DriverStatus == VerificationStatus.Verified, user.PassengerStatus == VerificationStatus.Verified, user.CreatedAt);
    }
}
