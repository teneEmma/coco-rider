using CocoRider.Api.Auth;
using CocoRider.Api.Features.Documents;
using CocoRider.Api.Features.Notifications;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure.Persistence;
using CocoRider.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Admin;

public sealed record ReviewQueueItem(Guid DocumentId, Guid UserId, string UserName, string PhoneNumber, DocumentType Type,
    DocumentStatus Status, DateOnly? ExpiresOn, string? ReviewNote, Uri ImageUrl, DateTimeOffset SubmittedAt);

public sealed record RejectDocumentRequest(string Reason);

public sealed record SuspendUserRequest(int Days, string Reason);

public sealed record AdminUserResponse(Guid Id, string PhoneNumber, string FirstName, string LastName, VerificationStatus PassengerStatus,
    VerificationStatus DriverStatus, int Strikes, DateTimeOffset? SuspendedUntil, string? SuspensionReason, DateTimeOffset CreatedAt)
{
    public static AdminUserResponse From(User u) => new(u.Id, u.PhoneNumber, u.FirstName, u.LastName, u.PassengerStatus,
        u.DriverStatus, u.Strikes.Count, u.SuspendedUntil, u.SuspensionReason, u.CreatedAt);
}

public sealed record StatsResponse(int Users, int VerifiedDrivers, int VerifiedPassengers, int DocumentsToReview,
    int UpcomingTrips, int BookingsLast30Days, long CommissionOwedLast30DaysXaf);

/// <summary>Endpoints for the admin dashboard. Callers must be in the Cognito "admin" group.</summary>
public static class AdminEndpoints
{
    public static void MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var admin = app.MapGroup("/v1/admin").WithTags("Admin").RequireAuthorization(Claims.AdminPolicy);
        admin.MapGet("/stats", StatsAsync);
        admin.MapGet("/documents", ReviewQueueAsync);
        admin.MapPost("/documents/{id:guid}/approve", ApproveAsync);
        admin.MapPost("/documents/{id:guid}/reject", RejectAsync);
        admin.MapGet("/users", SearchUsersAsync);
        admin.MapPost("/users/{id:guid}/suspend", SuspendAsync);
        admin.MapPost("/users/{id:guid}/unsuspend", UnsuspendAsync);
    }

    private static async Task<StatsResponse> StatsAsync(CocoRiderDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var monthAgo = now.AddDays(-30);
        var recentBookings = db.Bookings.Where(b => b.CreatedAt >= monthAgo);

        return new StatsResponse(
            await db.Users.CountAsync(ct),
            await db.Users.CountAsync(u => u.DriverStatus == VerificationStatus.Verified, ct),
            await db.Users.CountAsync(u => u.PassengerStatus == VerificationStatus.Verified, ct),
            await db.Documents.CountAsync(d => d.Status == DocumentStatus.NeedsReview && !d.IsSuperseded, ct),
            await db.Trips.CountAsync(t => t.Status == TripStatus.Scheduled && t.DepartureAt > now, ct),
            await recentBookings.CountAsync(ct),
            await recentBookings.Where(b => b.Status == BookingStatus.Completed).SumAsync(b => b.CommissionXaf, ct));
    }

    /// <summary>Documents the automatic checks could not accept, oldest first.</summary>
    private static async Task<IEnumerable<ReviewQueueItem>> ReviewQueueAsync(DocumentStatus? status, CocoRiderDbContext db,
        IDocumentStorage storage, CancellationToken ct)
    {
        var wanted = status ?? DocumentStatus.NeedsReview;
        var rows = await db.Documents.Where(d => d.Status == wanted && !d.IsSuperseded)
            .Join(db.Users, d => d.UserId, u => u.Id, (d, u) => new { d, u })
            .OrderBy(x => x.d.UpdatedAt)
            .Take(50)
            .ToListAsync(ct);

        var items = new List<ReviewQueueItem>(rows.Count);
        foreach (var row in rows)
        {
            var url = await storage.CreateDownloadUrlAsync(row.d.StorageKey, ct);
            items.Add(new ReviewQueueItem(row.d.Id, row.u.Id, $"{row.u.FirstName} {row.u.LastName}", row.u.PhoneNumber,
                row.d.Type, row.d.Status, row.d.ExpiresOn, row.d.ReviewNote, url, row.d.UpdatedAt));
        }
        return items;
    }

    private static Task<IResult> ApproveAsync(Guid id, CurrentUser current, CocoRiderDbContext db, VerificationService verification,
        Notifier notifier, TimeProvider clock, CancellationToken ct) =>
        DecideAsync(id, db, verification, notifier, ct, d => d.Approve(current.Sub, clock.GetUtcNow()));

    private static Task<IResult> RejectAsync(Guid id, RejectDocumentRequest request, CurrentUser current, CocoRiderDbContext db,
        VerificationService verification, Notifier notifier, TimeProvider clock, CancellationToken ct) =>
        DecideAsync(id, db, verification, notifier, ct, d => d.Reject(current.Sub, request.Reason, clock.GetUtcNow()));

    private static async Task<IResult> DecideAsync(Guid id, CocoRiderDbContext db, VerificationService verification,
        Notifier notifier, CancellationToken ct, Action<UserDocument> decide)
    {
        var document = await db.Documents.FirstOrDefaultAsync(d => d.Id == id, ct)
            ?? throw new NotFoundException("document.not_found", "Document not found.");
        var user = await db.Users.FirstAsync(u => u.Id == document.UserId, ct);

        decide(document);
        await db.SaveChangesAsync(ct);
        await verification.RefreshAsync(user, ct);
        await db.SaveChangesAsync(ct);
        notifier.DocumentReviewed(document);
        return Results.Ok(DocumentResponse.From(document));
    }

    private static async Task<IEnumerable<AdminUserResponse>> SearchUsersAsync(string? query, CocoRiderDbContext db, CancellationToken ct)
    {
        var users = db.Users.Include(u => u.Strikes).AsQueryable();
        if (!string.IsNullOrWhiteSpace(query))
        {
            var pattern = $"%{query.Trim()}%";
            users = users.Where(u => EF.Functions.ILike(u.PhoneNumber, pattern)
                || EF.Functions.ILike(u.FirstName, pattern)
                || EF.Functions.ILike(u.LastName, pattern));
        }

        var result = await users.OrderByDescending(u => u.CreatedAt).Take(50).ToListAsync(ct);
        return result.Select(AdminUserResponse.From);
    }

    private static async Task<AdminUserResponse> SuspendAsync(Guid id, SuspendUserRequest request, CocoRiderDbContext db,
        TimeProvider clock, CancellationToken ct)
    {
        if (request.Days < 1 || string.IsNullOrWhiteSpace(request.Reason))
            throw new DomainException("admin.invalid_suspension", "A duration of at least one day and a reason are required.");

        var user = await FindUserAsync(db, id, ct);
        user.Suspend(clock.GetUtcNow().AddDays(request.Days), request.Reason.Trim());
        await db.SaveChangesAsync(ct);
        return AdminUserResponse.From(user);
    }

    private static async Task<AdminUserResponse> UnsuspendAsync(Guid id, CocoRiderDbContext db, CancellationToken ct)
    {
        var user = await FindUserAsync(db, id, ct);
        user.LiftSuspension();
        await db.SaveChangesAsync(ct);
        return AdminUserResponse.From(user);
    }

    private static async Task<User> FindUserAsync(CocoRiderDbContext db, Guid id, CancellationToken ct) =>
        await db.Users.Include(u => u.Strikes).FirstOrDefaultAsync(u => u.Id == id, ct)
            ?? throw new NotFoundException("user.not_found", "User not found.");
}
