using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;

namespace CocoRider.Domain.Messaging;

/// <summary>A chat message between the passenger and the driver of a booking.</summary>
public sealed class Message
{
    public const int MaxLength = 1000;

    private Message() { }

    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid SenderId { get; private set; }
    public Guid RecipientId { get; private set; }
    public string Body { get; private set; } = null!;
    public DateTimeOffset SentAt { get; private set; }
    public DateTimeOffset? ReadAt { get; private set; }

    /// <summary>Participants can write while the booking is active and after the trip (lost items, thanks...).</summary>
    public static bool CanWrite(Booking booking) =>
        booking.Status is BookingStatus.Pending or BookingStatus.Confirmed or BookingStatus.Completed;

    public static Message Send(Booking booking, Trip trip, Guid senderId, string body, DateTimeOffset now)
    {
        var recipientId = Conversation.OtherParticipant(booking, trip, senderId);

        if (!CanWrite(booking))
            throw new DomainException("message.conversation_closed", "This conversation is closed.");
        var text = body?.Trim() ?? "";
        if (text.Length == 0)
            throw new DomainException("message.empty", "The message is empty.");
        if (text.Length > MaxLength)
            throw new DomainException("message.too_long", $"A message cannot exceed {MaxLength} characters.");

        return new Message
        {
            Id = Guid.NewGuid(),
            BookingId = booking.Id,
            SenderId = senderId,
            RecipientId = recipientId,
            Body = text,
            SentAt = now,
        };
    }

    public void MarkRead(DateTimeOffset now) => ReadAt ??= now;
}

public static class Conversation
{
    /// <summary>The passenger talks to the driver and the other way around; nobody else is allowed in.</summary>
    public static Guid OtherParticipant(Booking booking, Trip trip, Guid userId)
    {
        if (booking.TripId != trip.Id)
            throw new InvalidOperationException("The booking does not belong to this trip.");
        if (userId == booking.PassengerId)
            return trip.DriverId;
        if (userId == trip.DriverId)
            return booking.PassengerId;
        throw new NotFoundException("booking.not_found", "Booking not found.");
    }
}
