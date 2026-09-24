using CocoRider.Domain.Common;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Vehicles;

namespace CocoRider.Tests.Domain;

internal static class TestData
{
    public static readonly DateTimeOffset Now = new(2026, 10, 1, 8, 0, 0, TimeSpan.FromHours(1));
    public static readonly PlatformPolicy Policy = new();

    public static User VerifiedUser(Gender gender = Gender.Male, bool driver = false)
    {
        var user = new User($"sub-{Guid.NewGuid()}", "+237690000000", "Ada", "Nkemelu", gender, Language.French, Now);
        user.SetVerificationStatus(VerificationRole.Passenger, VerificationStatus.Verified);
        if (driver)
            user.SetVerificationStatus(VerificationRole.Driver, VerificationStatus.Verified);
        return user;
    }

    public static (User Driver, Trip Trip) PublishedTrip(
        DateTimeOffset? departure = null, int seats = 3, bool instantBooking = true, bool womenOnly = false)
    {
        var driver = VerifiedUser(womenOnly ? Gender.Female : Gender.Male, driver: true);
        var vehicle = new Vehicle(driver.Id, "Toyota", "Corolla", "Grise", "LT 123 AB", 4);
        var trip = Trip.Publish(driver, vehicle, TripKind.Intercity,
            new TripLocation("Douala", "Carrefour Ndokoti", 4.0511, 9.7679),
            new TripLocation("Yaoundé", "Total Mvan", 3.8480, 11.5021),
            departure ?? Now.AddDays(3), seats, 5000,
            new TripPreferences(womenOnly, LuggageAllowed: true, SmokingAllowed: false, instantBooking),
            null, Now, Policy);
        return (driver, trip);
    }
}
