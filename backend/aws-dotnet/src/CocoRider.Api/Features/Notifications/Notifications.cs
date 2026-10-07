using System.Globalization;
using System.Threading.Channels;
using CocoRider.Api.Features.Trips;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Messaging;
using CocoRider.Domain.Notifications;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure.Notifications;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features.Notifications;

/// <summary>A notification to send to all the phones of one user.</summary>
public sealed record PushNotification(
    Guid UserId,
    NotificationKind Kind,
    IReadOnlyDictionary<string, string> Args,
    Guid? TripId = null,
    Guid? BookingId = null);

/// <summary>
/// In-memory queue between the request and the sender, so API calls never wait for Firebase.
/// Notifications still queued when the container stops are lost; acceptable for the MVP.
/// </summary>
public sealed class NotificationQueue
{
    private readonly Channel<PushNotification> _channel = Channel.CreateUnbounded<PushNotification>();

    public ChannelReader<PushNotification> Reader => _channel.Reader;

    public void Enqueue(PushNotification notification) => _channel.Writer.TryWrite(notification);
}

/// <summary>Turns business events into notifications. Call it only after the change is saved.</summary>
public sealed class Notifier(NotificationQueue queue)
{
    public void BookingCreated(Booking booking, Trip trip, User passenger) =>
        queue.Enqueue(new(trip.DriverId,
            booking.Status == BookingStatus.Pending ? NotificationKind.NewBookingRequest : NotificationKind.NewBooking,
            TripArgs(trip, ("name", passenger.FirstName), ("seats", booking.Seats.ToString())), trip.Id, booking.Id));

    public void BookingCancelledByPassenger(Booking booking, Trip trip, User passenger) =>
        queue.Enqueue(new(trip.DriverId, NotificationKind.BookingCancelled,
            TripArgs(trip, ("name", passenger.FirstName)), trip.Id, booking.Id));

    public void BookingAnswered(Booking booking, Trip trip) =>
        ToPassenger(booking, trip, booking.Status == BookingStatus.Confirmed ? NotificationKind.BookingAccepted : NotificationKind.BookingRejected);

    /// <summary>After a trip changed state (cancelled, completed, lifecycle job): tells each affected passenger.</summary>
    public void TripOutcome(Trip trip, IEnumerable<Booking> changedBookings)
    {
        foreach (var booking in changedBookings)
        {
            var kind = booking.Status switch
            {
                BookingStatus.TripCancelled => NotificationKind.TripCancelled,
                BookingStatus.Expired => NotificationKind.BookingExpired,
                BookingStatus.Completed => NotificationKind.ReviewRequest,
                _ => (NotificationKind?)null,
            };
            if (kind is { } k)
                ToPassenger(booking, trip, k);
        }
    }

    public void DocumentReviewed(UserDocument document) =>
        queue.Enqueue(new(document.UserId,
            document.Status == DocumentStatus.Accepted ? NotificationKind.DocumentApproved : NotificationKind.DocumentRejected,
            new Dictionary<string, string>
            {
                ["document"] = document.Type.ToString(),
                ["reason"] = document.ReviewNote ?? "",
            }));

    public void NewMessage(Message message, Trip trip, User sender) =>
        queue.Enqueue(new(message.RecipientId, NotificationKind.NewMessage,
            new Dictionary<string, string>
            {
                ["name"] = sender.FirstName,
                ["text"] = message.Body.Length <= 140 ? message.Body : message.Body[..140] + "…",
            }, trip.Id, message.BookingId));

    public void TripStarted(Trip trip, User driver, IEnumerable<Guid> passengerIds)
    {
        foreach (var passengerId in passengerIds)
            queue.Enqueue(new(passengerId, NotificationKind.TripStarted, TripArgs(trip, ("name", driver.FirstName)), trip.Id));
    }

    private void ToPassenger(Booking booking, Trip trip, NotificationKind kind) =>
        queue.Enqueue(new(booking.PassengerId, kind, TripArgs(trip), trip.Id, booking.Id));

    private static Dictionary<string, string> TripArgs(Trip trip, params (string Key, string Value)[] extra)
    {
        var args = new Dictionary<string, string>
        {
            ["from"] = trip.Origin.City,
            ["to"] = trip.Destination.City,
            ["date"] = trip.DepartureAt.ToOffset(TripEndpoints.CameroonOffset).ToString("dd/MM HH:mm", CultureInfo.InvariantCulture),
        };
        foreach (var (key, value) in extra)
            args[key] = value;
        return args;
    }
}

/// <summary>Texts of the notifications, in the user's language.</summary>
public static class NotificationTexts
{
    private static readonly Dictionary<NotificationKind, (string Title, string Body)> French = new()
    {
        [NotificationKind.NewBooking] = ("Nouvelle réservation", "{name} a réservé {seats} place(s) pour {from} → {to} le {date}."),
        [NotificationKind.NewBookingRequest] = ("Nouvelle demande", "{name} demande {seats} place(s) pour {from} → {to} le {date}. Acceptez ou refusez."),
        [NotificationKind.BookingCancelled] = ("Réservation annulée", "{name} a annulé sa réservation pour {from} → {to} le {date}."),
        [NotificationKind.BookingAccepted] = ("Réservation confirmée", "Votre place pour {from} → {to} le {date} est confirmée."),
        [NotificationKind.BookingRejected] = ("Réservation refusée", "Le conducteur n'a pas accepté votre demande pour {from} → {to} le {date}."),
        [NotificationKind.BookingExpired] = ("Demande expirée", "Le conducteur n'a pas répondu à votre demande pour {from} → {to} le {date}."),
        [NotificationKind.TripCancelled] = ("Trajet annulé", "Le conducteur a annulé le trajet {from} → {to} du {date}."),
        [NotificationKind.ReviewRequest] = ("Comment s'est passé votre trajet ?", "Notez votre trajet {from} → {to}."),
        [NotificationKind.DocumentApproved] = ("Document accepté", "Votre document « {document} » a été accepté."),
        [NotificationKind.DocumentRejected] = ("Document refusé", "Votre document « {document} » a été refusé : {reason}"),
        [NotificationKind.NewMessage] = ("Message de {name}", "{text}"),
        [NotificationKind.TripStarted] = ("{name} est en route", "Suivez l'arrivée de votre conducteur pour {from} → {to} en direct."),
    };

    private static readonly Dictionary<NotificationKind, (string Title, string Body)> English = new()
    {
        [NotificationKind.NewBooking] = ("New booking", "{name} booked {seats} seat(s) for {from} → {to} on {date}."),
        [NotificationKind.NewBookingRequest] = ("New booking request", "{name} asks for {seats} seat(s) for {from} → {to} on {date}. Accept or decline."),
        [NotificationKind.BookingCancelled] = ("Booking cancelled", "{name} cancelled their booking for {from} → {to} on {date}."),
        [NotificationKind.BookingAccepted] = ("Booking confirmed", "Your seat for {from} → {to} on {date} is confirmed."),
        [NotificationKind.BookingRejected] = ("Booking declined", "The driver declined your request for {from} → {to} on {date}."),
        [NotificationKind.BookingExpired] = ("Request expired", "The driver did not answer your request for {from} → {to} on {date}."),
        [NotificationKind.TripCancelled] = ("Trip cancelled", "The driver cancelled the trip {from} → {to} on {date}."),
        [NotificationKind.ReviewRequest] = ("How was your trip?", "Rate your trip {from} → {to}."),
        [NotificationKind.DocumentApproved] = ("Document approved", "Your document \"{document}\" was approved."),
        [NotificationKind.DocumentRejected] = ("Document refused", "Your document \"{document}\" was refused: {reason}"),
        [NotificationKind.NewMessage] = ("Message from {name}", "{text}"),
        [NotificationKind.TripStarted] = ("{name} is on the way", "Follow your driver live for {from} → {to}."),
    };

    private static readonly Dictionary<DocumentType, (string French, string English)> Documents = new()
    {
        [DocumentType.NationalId] = ("CNI", "national ID card"),
        [DocumentType.Selfie] = ("selfie", "selfie"),
        [DocumentType.DriverLicence] = ("permis de conduire", "driving licence"),
        [DocumentType.Insurance] = ("attestation d'assurance", "insurance certificate"),
        [DocumentType.VehicleRegistration] = ("carte grise", "vehicle registration"),
    };

    public static PushMessage Render(PushNotification notification, Language language)
    {
        var english = language == Language.English;
        var (title, body) = (english ? English : French)[notification.Kind];

        foreach (var (key, raw) in notification.Args)
        {
            var value = key == "document" && Enum.TryParse<DocumentType>(raw, out var type)
                ? english ? Documents[type].English : Documents[type].French
                : raw;
            title = title.Replace($"{{{key}}}", value);
            body = body.Replace($"{{{key}}}", value);
        }

        var data = new Dictionary<string, string> { ["kind"] = notification.Kind.ToString() };
        if (notification.TripId is { } tripId) data["tripId"] = tripId.ToString();
        if (notification.BookingId is { } bookingId) data["bookingId"] = bookingId.ToString();

        return new PushMessage(title, body.Trim(), data);
    }
}

/// <summary>Sends queued notifications to every registered phone of the user.</summary>
public sealed class NotificationDispatcher(
    NotificationQueue queue,
    IServiceScopeFactory scopes,
    IPushSender sender,
    ILogger<NotificationDispatcher> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var notification in queue.Reader.ReadAllAsync(stoppingToken))
        {
            try
            {
                await SendAsync(notification, stoppingToken);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                logger.LogWarning(e, "Could not send {Kind} to user {UserId}", notification.Kind, notification.UserId);
            }
        }
    }

    private async Task SendAsync(PushNotification notification, CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CocoRiderDbContext>();

        var language = await db.Users.Where(u => u.Id == notification.UserId).Select(u => (Language?)u.Language).FirstOrDefaultAsync(ct);
        var tokens = await db.DeviceTokens.Where(d => d.UserId == notification.UserId).Select(d => d.Token).ToListAsync(ct);
        if (language is null || tokens.Count == 0)
            return;

        var invalid = await sender.SendAsync(tokens, NotificationTexts.Render(notification, language.Value), ct);
        if (invalid.Count > 0)
            await db.DeviceTokens.Where(d => invalid.Contains(d.Token)).ExecuteDeleteAsync(ct);
    }
}
