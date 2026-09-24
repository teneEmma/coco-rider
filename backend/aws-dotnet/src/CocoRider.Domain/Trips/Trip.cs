using CocoRider.Domain.Common;
using CocoRider.Domain.Users;
using CocoRider.Domain.Vehicles;

namespace CocoRider.Domain.Trips;

public enum TripKind
{
    /// <summary>Between cities, e.g. Douala → Yaoundé.</summary>
    Intercity,

    /// <summary>A commute inside a city.</summary>
    Urban,
}

public enum TripStatus
{
    Scheduled,
    Cancelled,
    Completed,
}

public sealed record TripPreferences(bool WomenOnly, bool LuggageAllowed, bool SmokingAllowed, bool InstantBooking);

public sealed class Trip
{
    public const long MaxPricePerSeatXaf = 100_000;

    private Trip() { }

    private Trip(Guid driverId, Guid vehicleId, TripKind kind, TripLocation origin, TripLocation destination,
        DateTimeOffset departureAt, int seats, long pricePerSeatXaf, TripPreferences preferences, string? notes, DateTimeOffset now)
    {
        Id = Guid.NewGuid();
        DriverId = driverId;
        VehicleId = vehicleId;
        Kind = kind;
        Origin = origin;
        Destination = destination;
        // PostgreSQL timestamptz only stores UTC; clients may send local (+01:00) times.
        DepartureAt = departureAt.ToUniversalTime();
        SeatsTotal = seats;
        SeatsAvailable = seats;
        PricePerSeatXaf = pricePerSeatXaf;
        WomenOnly = preferences.WomenOnly;
        LuggageAllowed = preferences.LuggageAllowed;
        SmokingAllowed = preferences.SmokingAllowed;
        InstantBooking = preferences.InstantBooking;
        Notes = string.IsNullOrWhiteSpace(notes) ? null : notes.Trim();
        Status = TripStatus.Scheduled;
        CreatedAt = now;
    }

    public Guid Id { get; private set; }
    public Guid DriverId { get; private set; }
    public Guid VehicleId { get; private set; }
    public TripKind Kind { get; private set; }
    public TripLocation Origin { get; private set; } = null!;
    public TripLocation Destination { get; private set; } = null!;
    public DateTimeOffset DepartureAt { get; private set; }
    public int SeatsTotal { get; private set; }
    public int SeatsAvailable { get; private set; }

    /// <summary>Price in FCFA (XAF has no minor unit).</summary>
    public long PricePerSeatXaf { get; private set; }

    public bool WomenOnly { get; private set; }
    public bool LuggageAllowed { get; private set; }
    public bool SmokingAllowed { get; private set; }

    /// <summary>When false the driver accepts or rejects each booking request.</summary>
    public bool InstantBooking { get; private set; }

    public string? Notes { get; private set; }
    public TripStatus Status { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset? CancelledAt { get; private set; }

    /// <summary>Optimistic concurrency token (PostgreSQL xmin) so two passengers cannot take the last seat.</summary>
    public uint Version { get; private set; }

    public static Trip Publish(User driver, Vehicle vehicle, TripKind kind, TripLocation origin, TripLocation destination,
        DateTimeOffset departureAt, int seats, long pricePerSeatXaf, TripPreferences preferences, string? notes,
        DateTimeOffset now, PlatformPolicy policy)
    {
        driver.EnsureCanDrive(now);

        if (vehicle.OwnerId != driver.Id || vehicle.IsArchived)
            throw new DomainException("trip.invalid_vehicle", "This vehicle cannot be used for a trip.");
        if (departureAt < now.AddMinutes(policy.MinimumMinutesBeforeDeparture))
            throw new DomainException("trip.departure_too_soon", $"The departure must be at least {policy.MinimumMinutesBeforeDeparture} minutes from now.");
        if (seats < 1 || seats > vehicle.PassengerSeats)
            throw new DomainException("trip.invalid_seats", $"Seats must be between 1 and {vehicle.PassengerSeats}.");
        if (pricePerSeatXaf is <= 0 or > MaxPricePerSeatXaf)
            throw new DomainException("trip.invalid_price", $"The price per seat must be between 1 and {MaxPricePerSeatXaf} FCFA.");
        if (preferences.WomenOnly && driver.Gender != Gender.Female)
            throw new DomainException("trip.women_only_requires_female_driver", "Only female drivers can publish women-only trips.");

        return new Trip(driver.Id, vehicle.Id, kind, origin, destination, departureAt, seats, pricePerSeatXaf, preferences, notes, now);
    }

    public bool HasDeparted(DateTimeOffset now) => DepartureAt <= now;

    public bool IsWithinCancellationWindow(DateTimeOffset now, PlatformPolicy policy) =>
        DepartureAt - now < policy.CancellationWindow;

    internal void ReserveSeats(int seats)
    {
        if (Status != TripStatus.Scheduled)
            throw new DomainException("trip.not_bookable", "This trip can no longer be booked.");
        if (seats > SeatsAvailable)
            throw new DomainException("trip.not_enough_seats", "Not enough seats are available on this trip.");
        SeatsAvailable -= seats;
    }

    internal void ReleaseSeats(int seats) => SeatsAvailable = Math.Min(SeatsTotal, SeatsAvailable + seats);

    /// <summary>
    /// Cancels the trip. Returns true when the cancellation is late (inside the cancellation window);
    /// the caller then records a strike against the driver and notifies the passengers.
    /// </summary>
    public bool Cancel(Guid driverId, DateTimeOffset now, PlatformPolicy policy)
    {
        EnsureDriver(driverId);
        if (Status != TripStatus.Scheduled)
            throw new DomainException("trip.not_cancellable", "This trip cannot be cancelled.");
        if (HasDeparted(now))
            throw new DomainException("trip.already_departed", "This trip has already departed.");

        Status = TripStatus.Cancelled;
        CancelledAt = now;
        return IsWithinCancellationWindow(now, policy);
    }

    public void Complete(Guid driverId, DateTimeOffset now)
    {
        EnsureDriver(driverId);
        if (Status != TripStatus.Scheduled)
            throw new DomainException("trip.not_completable", "This trip cannot be completed.");
        if (!HasDeparted(now))
            throw new DomainException("trip.not_departed", "A trip can only be completed after its departure time.");

        Status = TripStatus.Completed;
    }

    public void EnsureDriver(Guid userId)
    {
        if (userId != DriverId)
            throw new ForbiddenException("trip.not_driver", "Only the driver of this trip can do this.");
    }
}
