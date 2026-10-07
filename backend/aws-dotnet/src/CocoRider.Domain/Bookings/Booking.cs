using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;

namespace CocoRider.Domain.Bookings;

public enum BookingStatus
{
    /// <summary>Waiting for the driver (trips without instant booking). Seats are held meanwhile.</summary>
    Pending,

    Confirmed,
    RejectedByDriver,
    CancelledByPassenger,

    /// <summary>The driver cancelled the whole trip.</summary>
    TripCancelled,

    Completed,
    NoShow,

    /// <summary>The driver never answered the request before departure.</summary>
    Expired,
}

/// <summary>How the passenger will pay the driver. The app does not collect money in the MVP.</summary>
public enum PaymentMethod
{
    Cash,
    MtnMobileMoney,
    OrangeMoney,
}

public sealed class Booking
{
    public const int MaxSeatsPerBooking = 4;

    private Booking() { }

    public Guid Id { get; private set; }
    public Guid TripId { get; private set; }
    public Guid PassengerId { get; private set; }
    public int Seats { get; private set; }
    public BookingStatus Status { get; private set; }
    public PaymentMethod PaymentMethod { get; private set; }

    /// <summary>Total price paid to the driver, in FCFA.</summary>
    public long TotalPriceXaf { get; private set; }

    /// <summary>Commission owed to the platform for this booking (0 while the platform is free).</summary>
    public long CommissionXaf { get; private set; }

    public int CommissionRateBasisPoints { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    public bool HoldsSeats => Status is BookingStatus.Pending or BookingStatus.Confirmed;

    public static Booking Request(Trip trip, User passenger, int seats, PaymentMethod paymentMethod, DateTimeOffset now, PlatformPolicy policy)
    {
        passenger.EnsureCanTravel(now);

        if (passenger.Id == trip.DriverId)
            throw new DomainException("booking.own_trip", "You cannot book your own trip.");
        if (trip.HasDeparted(now))
            throw new DomainException("booking.trip_departed", "This trip has already departed.");
        if (seats is < 1 or > MaxSeatsPerBooking)
            throw new DomainException("booking.invalid_seats", $"You can book between 1 and {MaxSeatsPerBooking} seats.");

        trip.ReserveSeats(seats);

        var total = trip.PricePerSeatXaf * seats;
        return new Booking
        {
            Id = Guid.NewGuid(),
            TripId = trip.Id,
            PassengerId = passenger.Id,
            Seats = seats,
            PaymentMethod = paymentMethod,
            Status = trip.InstantBooking ? BookingStatus.Confirmed : BookingStatus.Pending,
            TotalPriceXaf = total,
            CommissionRateBasisPoints = policy.CommissionRateBasisPoints,
            CommissionXaf = policy.CommissionFor(total),
            CreatedAt = now,
            UpdatedAt = now,
        };
    }

    public void Accept(Trip trip, Guid driverId, DateTimeOffset now)
    {
        EnsureTrip(trip);
        trip.EnsureDriver(driverId);
        EnsureStatus(BookingStatus.Pending, "booking.not_pending");
        if (trip.HasDeparted(now))
            throw new DomainException("booking.trip_departed", "This trip has already departed.");

        Move(BookingStatus.Confirmed, now);
    }

    public void Reject(Trip trip, Guid driverId, DateTimeOffset now)
    {
        EnsureTrip(trip);
        trip.EnsureDriver(driverId);
        EnsureStatus(BookingStatus.Pending, "booking.not_pending");

        trip.ReleaseSeats(Seats);
        Move(BookingStatus.RejectedByDriver, now);
    }

    /// <summary>Free cancellation until the window opens; inside the window the booking can no longer be cancelled.</summary>
    public void CancelByPassenger(Trip trip, Guid passengerId, DateTimeOffset now, PlatformPolicy policy)
    {
        EnsureTrip(trip);
        EnsurePassenger(passengerId);
        if (!HoldsSeats)
            throw new DomainException("booking.not_cancellable", "This booking cannot be cancelled.");

        // A request the driver has not accepted yet can always be withdrawn.
        if (Status == BookingStatus.Confirmed && trip.IsWithinCancellationWindow(now, policy))
            throw new DomainException("booking.cancellation_window_closed",
                $"Bookings cannot be cancelled less than {policy.CancellationWindowHours} hours before departure.");

        trip.ReleaseSeats(Seats);
        Move(BookingStatus.CancelledByPassenger, now);
    }

    /// <summary>Called for every booking when the driver cancels the trip.</summary>
    public void CancelBecauseTripCancelled(DateTimeOffset now)
    {
        if (HoldsSeats)
            Move(BookingStatus.TripCancelled, now);
    }

    /// <summary>Called for every booking when the trip is completed; unanswered requests expire.</summary>
    public void CompleteWithTrip(DateTimeOffset now)
    {
        if (Status == BookingStatus.Confirmed)
            Move(BookingStatus.Completed, now);
        else if (Status == BookingStatus.Pending)
            Move(BookingStatus.Expired, now);
    }

    /// <summary>A request the driver did not answer before departure stops holding seats.</summary>
    public void ExpireIfUnanswered(Trip trip, DateTimeOffset now)
    {
        EnsureTrip(trip);
        if (Status != BookingStatus.Pending || !trip.HasDeparted(now))
            return;

        trip.ReleaseSeats(Seats);
        Move(BookingStatus.Expired, now);
    }

    /// <summary>The driver reports that the passenger did not show up. The caller records a strike.</summary>
    public void MarkNoShow(Trip trip, Guid driverId, DateTimeOffset now)
    {
        EnsureTrip(trip);
        trip.EnsureDriver(driverId);
        if (Status is not (BookingStatus.Confirmed or BookingStatus.Completed))
            throw new DomainException("booking.not_confirmed", "Only confirmed bookings can be marked as no-show.");
        if (!trip.HasDeparted(now))
            throw new DomainException("booking.trip_not_departed", "A no-show can only be reported after departure.");

        Move(BookingStatus.NoShow, now);
    }

    public void EnsurePassenger(Guid userId)
    {
        if (userId != PassengerId)
            throw new ForbiddenException("booking.not_passenger", "Only the passenger of this booking can do this.");
    }

    private void EnsureTrip(Trip trip)
    {
        if (trip.Id != TripId)
            throw new InvalidOperationException("The booking does not belong to this trip.");
    }

    private void EnsureStatus(BookingStatus expected, string code)
    {
        if (Status != expected)
            throw new DomainException(code, $"The booking must be {expected}.");
    }

    private void Move(BookingStatus status, DateTimeOffset now)
    {
        Status = status;
        UpdatedAt = now;
    }
}
