using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Vehicles;
using static CocoRider.Tests.Domain.TestData;

namespace CocoRider.Tests.Domain;

public class TripAndUserTests
{
    [Fact]
    public void Unverified_driver_cannot_publish()
    {
        var driver = VerifiedUser(driver: false);
        var vehicle = new Vehicle(driver.Id, "Toyota", "Yaris", "Blanche", "CE-456-XY", 4);

        var error = Assert.Throws<DomainException>(() => Trip.Publish(driver, vehicle, TripKind.Urban,
            new TripLocation("Douala", "Akwa", 4.05, 9.70), new TripLocation("Douala", "Bonamoussadi", 4.09, 9.74),
            Now.AddHours(2), 2, 500, new TripPreferences(true, false, true), null, Now, Policy));

        Assert.Equal("verification.driver_not_verified", error.Code);
    }

    [Fact]
    public void Seats_cannot_exceed_vehicle_capacity()
    {
        var error = Assert.Throws<DomainException>(() => PublishedTrip(seats: 5));
        Assert.Equal("trip.invalid_seats", error.Code);
    }

    [Fact]
    public void Late_driver_cancellation_is_reported()
    {
        var (driver, early) = PublishedTrip(departure: Now.AddDays(2));
        Assert.False(early.Cancel(driver.Id, Now, Policy));

        var (driver2, late) = PublishedTrip(departure: Now.AddHours(5));
        Assert.True(late.Cancel(driver2.Id, Now, Policy));
        Assert.Equal(TripStatus.Cancelled, late.Status);
    }

    [Fact]
    public void Third_strike_suspends_the_user()
    {
        var user = VerifiedUser();

        user.AddStrike(StrikeReason.PassengerNoShow, null, Now, Policy);
        user.AddStrike(StrikeReason.PassengerNoShow, null, Now.AddDays(10), Policy);
        Assert.False(user.IsSuspended(Now.AddDays(10)));

        user.AddStrike(StrikeReason.PassengerNoShow, null, Now.AddDays(20), Policy);
        Assert.True(user.IsSuspended(Now.AddDays(20)));
        Assert.Equal(Now.AddDays(50), user.SuspendedUntil);

        var error = Assert.Throws<DomainException>(() => user.EnsureCanTravel(Now.AddDays(21)));
        Assert.Equal("account.suspended", error.Code);
    }

    [Fact]
    public void Old_strikes_do_not_count()
    {
        var user = VerifiedUser();
        user.AddStrike(StrikeReason.PassengerNoShow, null, Now, Policy);
        user.AddStrike(StrikeReason.PassengerNoShow, null, Now.AddDays(1), Policy);

        user.AddStrike(StrikeReason.PassengerNoShow, null, Now.AddDays(200), Policy);

        Assert.False(user.IsSuspended(Now.AddDays(200)));
    }

    [Theory]
    [InlineData("lt 123-ab", "LT123AB")]
    [InlineData("CE 456 XY", "CE456XY")]
    public void Plate_numbers_are_normalized(string input, string expected) =>
        Assert.Equal(expected, Vehicle.NormalizePlate(input));
}

public class GeoTests
{
    [Fact]
    public void Douala_to_Yaounde_is_about_200_km_as_the_crow_flies() =>
        Assert.InRange(CocoRider.Domain.Tracking.Geo.DistanceKm(4.0511, 9.7679, 3.8480, 11.5021), 190, 200);
}
