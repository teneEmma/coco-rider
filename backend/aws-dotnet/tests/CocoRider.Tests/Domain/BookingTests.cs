using CocoRider.Domain.Bookings;
using CocoRider.Domain.Common;
using CocoRider.Domain.Users;
using static CocoRider.Tests.Domain.TestData;

namespace CocoRider.Tests.Domain;

public class BookingTests
{
    [Fact]
    public void Instant_booking_is_confirmed_and_takes_seats()
    {
        var (_, trip) = PublishedTrip(seats: 3);

        var booking = Booking.Request(trip, VerifiedUser(), 2, PaymentMethod.MtnMobileMoney, Now, Policy);

        Assert.Equal(BookingStatus.Confirmed, booking.Status);
        Assert.Equal(1, trip.SeatsAvailable);
        Assert.Equal(10_000, booking.TotalPriceXaf);
    }

    [Fact]
    public void Booking_request_waits_for_driver_but_holds_seats()
    {
        var (driver, trip) = PublishedTrip(instantBooking: false);

        var booking = Booking.Request(trip, VerifiedUser(), 1, PaymentMethod.Cash, Now, Policy);
        Assert.Equal(BookingStatus.Pending, booking.Status);
        Assert.Equal(2, trip.SeatsAvailable);

        booking.Reject(trip, driver.Id, Now);
        Assert.Equal(BookingStatus.RejectedByDriver, booking.Status);
        Assert.Equal(3, trip.SeatsAvailable);
    }

    [Fact]
    public void Cannot_overbook()
    {
        var (_, trip) = PublishedTrip(seats: 1);
        Booking.Request(trip, VerifiedUser(), 1, PaymentMethod.Cash, Now, Policy);

        var error = Assert.Throws<DomainException>(() => Booking.Request(trip, VerifiedUser(), 1, PaymentMethod.Cash, Now, Policy));
        Assert.Equal("trip.not_enough_seats", error.Code);
    }

    [Fact]
    public void Unverified_passenger_cannot_book()
    {
        var (_, trip) = PublishedTrip();
        var passenger = new User("sub", "+237690000001", "Paul", "Biya", Gender.Male, Language.English, Now);

        var error = Assert.Throws<DomainException>(() => Booking.Request(trip, passenger, 1, PaymentMethod.Cash, Now, Policy));
        Assert.Equal("verification.passenger_not_verified", error.Code);
    }

    [Fact]
    public void Women_only_trip_rejects_male_passengers()
    {
        var (_, trip) = PublishedTrip(womenOnly: true);

        var error = Assert.Throws<DomainException>(() =>
            Booking.Request(trip, VerifiedUser(Gender.Male), 1, PaymentMethod.Cash, Now, Policy));
        Assert.Equal("booking.women_only", error.Code);

        Booking.Request(trip, VerifiedUser(Gender.Female), 1, PaymentMethod.Cash, Now, Policy);
    }

    [Fact]
    public void Free_cancellation_more_than_24_hours_before_departure()
    {
        var (_, trip) = PublishedTrip(departure: Now.AddHours(25));
        var passenger = VerifiedUser();
        var booking = Booking.Request(trip, passenger, 2, PaymentMethod.Cash, Now, Policy);

        booking.CancelByPassenger(trip, passenger.Id, Now, Policy);

        Assert.Equal(BookingStatus.CancelledByPassenger, booking.Status);
        Assert.Equal(3, trip.SeatsAvailable);
    }

    [Fact]
    public void Confirmed_booking_cannot_be_cancelled_within_24_hours()
    {
        var (_, trip) = PublishedTrip(departure: Now.AddHours(23));
        var passenger = VerifiedUser();
        var booking = Booking.Request(trip, passenger, 1, PaymentMethod.Cash, Now, Policy);

        var error = Assert.Throws<DomainException>(() => booking.CancelByPassenger(trip, passenger.Id, Now, Policy));
        Assert.Equal("booking.cancellation_window_closed", error.Code);
    }

    [Fact]
    public void Pending_request_can_always_be_withdrawn()
    {
        var (_, trip) = PublishedTrip(departure: Now.AddHours(2), instantBooking: false);
        var passenger = VerifiedUser();
        var booking = Booking.Request(trip, passenger, 1, PaymentMethod.Cash, Now, Policy);

        booking.CancelByPassenger(trip, passenger.Id, Now, Policy);

        Assert.Equal(BookingStatus.CancelledByPassenger, booking.Status);
    }

    [Fact]
    public void Commission_is_recorded_from_policy()
    {
        var (_, trip) = PublishedTrip();
        var policy = new PlatformPolicy { CommissionRateBasisPoints = 750 };

        var booking = Booking.Request(trip, VerifiedUser(), 3, PaymentMethod.OrangeMoney, Now, policy);

        Assert.Equal(15_000, booking.TotalPriceXaf);
        Assert.Equal(1_125, booking.CommissionXaf);
    }

    [Fact]
    public void No_show_only_after_departure()
    {
        var (driver, trip) = PublishedTrip(departure: Now.AddHours(1));
        var booking = Booking.Request(trip, VerifiedUser(), 1, PaymentMethod.Cash, Now, Policy);

        Assert.Throws<DomainException>(() => booking.MarkNoShow(trip, driver.Id, Now));

        booking.MarkNoShow(trip, driver.Id, Now.AddHours(2));
        Assert.Equal(BookingStatus.NoShow, booking.Status);
    }

    [Fact]
    public void Only_the_driver_can_accept()
    {
        var (_, trip) = PublishedTrip(instantBooking: false);
        var passenger = VerifiedUser();
        var booking = Booking.Request(trip, passenger, 1, PaymentMethod.Cash, Now, Policy);

        Assert.Throws<ForbiddenException>(() => booking.Accept(trip, passenger.Id, Now));
    }
}
