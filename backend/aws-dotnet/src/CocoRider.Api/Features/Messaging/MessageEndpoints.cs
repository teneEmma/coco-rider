using CocoRider.Api.Auth;
using CocoRider.Api.Features.Notifications;
using CocoRider.Api.Features.Trips;
using CocoRider.Domain.Common;
using CocoRider.Domain.Messaging;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Messaging;

public sealed record SendMessageRequest(string Body);

public sealed record MessageResponse(Guid Id, bool FromMe, string Body, DateTimeOffset SentAt, DateTimeOffset? ReadAt);

public sealed record Participant(Guid Id, string FirstName);

public sealed record ConversationResponse(Guid BookingId, Guid TripId, Participant With, bool CanWrite,
    IReadOnlyList<MessageResponse> Messages);

public sealed record ConversationSummary(Guid BookingId, Guid TripId, Participant With, string From, string To,
    DateTimeOffset DepartureAt, MessageResponse LastMessage, int Unread);

/// <summary>
/// Chat between the passenger and the driver of a booking. The app polls
/// GET .../messages?after= while the chat is open; a push notification announces new messages otherwise.
/// </summary>
public static class MessageEndpoints
{
    private const int PageSize = 200;

    public static void MapMessageEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/v1/bookings/{id:guid}/messages").WithTags("Messages");
        group.MapGet("/", GetAsync);
        group.MapPost("/", SendAsync);
        app.MapGet("/v1/me/conversations", ListAsync).WithTags("Messages");
    }

    /// <summary>Messages of the conversation (only those after <paramref name="after"/> if given); marks received ones as read.</summary>
    private static async Task<ConversationResponse> GetAsync(Guid id, DateTimeOffset? after, CurrentUser current,
        CocoRiderDbContext db, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.RequireProfileAsync(ct);
        var (booking, trip) = await FindAsync(db, id, ct);
        var otherId = Conversation.OtherParticipant(booking, trip, me.Id);

        var query = db.Messages.Where(m => m.BookingId == id);
        if (after is { } since)
        {
            var sinceUtc = since.ToUniversalTime();
            query = query.Where(m => m.SentAt > sinceUtc);
        }
        var messages = await query.OrderBy(m => m.SentAt).Take(PageSize).ToListAsync(ct);

        var now = clock.GetUtcNow();
        var unread = messages.Where(m => m.RecipientId == me.Id && m.ReadAt is null).ToList();
        if (unread.Count > 0)
        {
            unread.ForEach(m => m.MarkRead(now));
            await db.SaveChangesAsync(ct);
        }

        var other = await db.Users.Where(u => u.Id == otherId).Select(u => new Participant(u.Id, u.FirstName)).FirstAsync(ct);
        return new ConversationResponse(booking.Id, trip.Id, other, Message.CanWrite(booking),
            messages.Select(m => ToResponse(m, me.Id)).ToList());
    }

    private static async Task<IResult> SendAsync(Guid id, SendMessageRequest request, CurrentUser current,
        CocoRiderDbContext db, Notifier notifier, TimeProvider clock, CancellationToken ct)
    {
        var me = await current.RequireProfileAsync(ct);
        var (booking, trip) = await FindAsync(db, id, ct);

        var message = Message.Send(booking, trip, me.Id, request.Body, clock.GetUtcNow());
        db.Messages.Add(message);
        await db.SaveChangesAsync(ct);
        notifier.NewMessage(message, trip, me);

        return Results.Created($"/v1/bookings/{id}/messages", ToResponse(message, me.Id));
    }

    /// <summary>The inbox: conversations that have at least one message, most recent first.</summary>
    private static async Task<IEnumerable<ConversationSummary>> ListAsync(CurrentUser current, CocoRiderDbContext db, CancellationToken ct)
    {
        var me = await current.RequireProfileAsync(ct);

        var mine = db.Messages.Where(m => m.SenderId == me.Id || m.RecipientId == me.Id);
        var lastIds = await mine
            .GroupBy(m => m.BookingId)
            .Select(g => g.OrderByDescending(m => m.SentAt).First().Id)
            .ToListAsync(ct);
        var lastMessages = await db.Messages.Where(m => lastIds.Contains(m.Id))
            .OrderByDescending(m => m.SentAt).Take(100).ToListAsync(ct);
        var unread = await mine.Where(m => m.RecipientId == me.Id && m.ReadAt == null)
            .GroupBy(m => m.BookingId)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Key, g => g.Count, ct);

        var bookingIds = lastMessages.Select(m => m.BookingId).ToList();
        var rows = await db.Bookings.Where(b => bookingIds.Contains(b.Id))
            .Join(db.Trips, b => b.TripId, t => t.Id, (b, t) => new { b, t })
            .ToDictionaryAsync(x => x.b.Id, ct);
        var otherIds = lastMessages.Select(m => m.SenderId == me.Id ? m.RecipientId : m.SenderId).Distinct().ToList();
        var names = await db.Users.Where(u => otherIds.Contains(u.Id)).ToDictionaryAsync(u => u.Id, u => u.FirstName, ct);

        return lastMessages.Select(m =>
        {
            var row = rows[m.BookingId];
            var otherId = m.SenderId == me.Id ? m.RecipientId : m.SenderId;
            return new ConversationSummary(m.BookingId, row.t.Id, new Participant(otherId, names[otherId]),
                row.t.Origin.City, row.t.Destination.City, row.t.DepartureAt, ToResponse(m, me.Id), unread.GetValueOrDefault(m.BookingId));
        });
    }

    private static async Task<(Domain.Bookings.Booking, Domain.Trips.Trip)> FindAsync(CocoRiderDbContext db, Guid bookingId, CancellationToken ct)
    {
        var booking = await db.Bookings.FirstOrDefaultAsync(b => b.Id == bookingId, ct)
            ?? throw new NotFoundException("booking.not_found", "Booking not found.");
        return (booking, await TripEndpoints.FindTripAsync(db, booking.TripId, ct));
    }

    private static MessageResponse ToResponse(Message m, Guid me) => new(m.Id, m.SenderId == me, m.Body, m.SentAt, m.ReadAt);
}
