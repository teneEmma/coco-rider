namespace CocoRider.Domain.Users;

public enum StrikeReason
{
    PassengerNoShow,
    DriverLateCancellation,
    AdminDecision,
}

/// <summary>A penalty recorded against a user. Too many strikes lead to a suspension.</summary>
public sealed class Strike
{
    private Strike() { }

    public Strike(Guid userId, StrikeReason reason, Guid? bookingId, DateTimeOffset createdAt)
    {
        Id = Guid.NewGuid();
        UserId = userId;
        Reason = reason;
        BookingId = bookingId;
        CreatedAt = createdAt;
    }

    public Guid Id { get; private set; }
    public Guid UserId { get; private set; }
    public StrikeReason Reason { get; private set; }
    public Guid? BookingId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
}
