namespace CocoRider.Domain.Notifications;

public enum DevicePlatform
{
    Android,
    Ios,
    Web,
}

/// <summary>A Firebase Cloud Messaging registration token of one of the user's phones.</summary>
public sealed class DeviceToken
{
    private DeviceToken() { }

    public DeviceToken(Guid userId, string token, DevicePlatform platform, DateTimeOffset now)
    {
        Id = Guid.NewGuid();
        Token = token;
        Assign(userId, platform, now);
    }

    public Guid Id { get; private set; }
    public Guid UserId { get; private set; }
    public string Token { get; private set; } = null!;
    public DevicePlatform Platform { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    /// <summary>A phone changes hands when another account signs in on it.</summary>
    public void Assign(Guid userId, DevicePlatform platform, DateTimeOffset now)
    {
        UserId = userId;
        Platform = platform;
        UpdatedAt = now;
    }
}

public enum NotificationKind
{
    /// <summary>To the driver: a passenger booked (instant booking).</summary>
    NewBooking,

    /// <summary>To the driver: a passenger asks for seats.</summary>
    NewBookingRequest,

    /// <summary>To the driver: a passenger cancelled.</summary>
    BookingCancelled,

    /// <summary>To the passenger.</summary>
    BookingAccepted,

    /// <summary>To the passenger.</summary>
    BookingRejected,

    /// <summary>To the passenger: the driver did not answer before departure.</summary>
    BookingExpired,

    /// <summary>To the passenger: the driver cancelled the trip.</summary>
    TripCancelled,

    /// <summary>To the passenger: the trip is over, rate the driver.</summary>
    ReviewRequest,

    DocumentApproved,
    DocumentRejected,

    /// <summary>A chat message from the other participant of a booking.</summary>
    NewMessage,

    /// <summary>To confirmed passengers: the driver started sharing their position.</summary>
    TripStarted,
}
