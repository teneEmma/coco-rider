using System.Net;
using System.Net.Http.Json;
using CocoRider.Api.Features.Admin;
using CocoRider.Api.Features.Bookings;
using CocoRider.Api.Features.Documents;
using CocoRider.Api.Features.Profile;
using CocoRider.Api.Features.Trips;
using CocoRider.Api.Features.Vehicles;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Verification;

namespace CocoRider.Tests.Api;

/// <summary>End-to-end scenarios through HTTP, the domain and PostgreSQL/PostGIS.</summary>
public class CarpoolingFlowTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    private static int _phoneCounter = 10_000;

    [Fact]
    public async Task Driver_publishes_and_passenger_books_an_intercity_trip()
    {
        var (driver, _) = await SignUpAsync(Gender.Male, asDriver: true);
        var trip = await PublishDoualaYaoundeAsync(driver, seats: 3, departure: api.Clock.GetUtcNow().AddDays(2));

        var (passenger, _) = await SignUpAsync(Gender.Female, asDriver: false);

        // Intercity search by city name, and by GPS position within 5 km of Ndokoti.
        var date = DateOnly.FromDateTime(trip.DepartureAt.ToOffset(TripEndpoints.CameroonOffset).DateTime);
        var byCity = await passenger.GetFromJsonAsync<List<TripResponse>>(
            $"/v1/trips/search?date={date:yyyy-MM-dd}&fromCity=douala&toCity=Yaoundé", ApiFactory.Json);
        var byGps = await passenger.GetFromJsonAsync<List<TripResponse>>(
            $"/v1/trips/search?date={date:yyyy-MM-dd}&fromLat=4.06&fromLng=9.77&toLat=3.85&toLng=11.50&radiusKm=5", ApiFactory.Json);
        var farAway = await passenger.GetFromJsonAsync<List<TripResponse>>(
            $"/v1/trips/search?date={date:yyyy-MM-dd}&fromLat=5.48&fromLng=10.42&radiusKm=5", ApiFactory.Json);

        Assert.Contains(byCity!, t => t.Id == trip.Id);
        Assert.Contains(byGps!, t => t.Id == trip.Id);
        Assert.DoesNotContain(farAway!, t => t.Id == trip.Id);

        var booking = await passenger.PostAsync<BookingResponse>($"/v1/trips/{trip.Id}/bookings",
            new CreateBookingRequest(2, PaymentMethod.OrangeMoney));

        Assert.Equal(BookingStatus.Confirmed, booking.Status);
        Assert.Equal(10_000, booking.TotalPriceXaf);
        Assert.Equal(1, booking.Trip.SeatsAvailable);
        Assert.NotNull(booking.DriverPhone);

        var details = await driver.GetFromJsonAsync<TripDetailsResponse>($"/v1/trips/{trip.Id}", ApiFactory.Json);
        Assert.Single(details!.Bookings!);
    }

    [Fact]
    public async Task Booking_cannot_be_cancelled_within_24_hours()
    {
        var (driver, _) = await SignUpAsync(Gender.Male, asDriver: true);
        var trip = await PublishDoualaYaoundeAsync(driver, seats: 2, departure: api.Clock.GetUtcNow().AddHours(20));
        var (passenger, _) = await SignUpAsync(Gender.Male, asDriver: false);
        var booking = await passenger.PostAsync<BookingResponse>($"/v1/trips/{trip.Id}/bookings",
            new CreateBookingRequest(1, PaymentMethod.Cash));

        var response = await passenger.PostAsJsonAsync($"/v1/bookings/{booking.Id}/cancel", new { });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("booking.cancellation_window_closed", await response.ErrorCodeAsync());
    }

    [Fact]
    public async Task Last_seat_goes_to_exactly_one_passenger()
    {
        var (driver, _) = await SignUpAsync(Gender.Male, asDriver: true);
        var trip = await PublishDoualaYaoundeAsync(driver, seats: 1, departure: api.Clock.GetUtcNow().AddDays(3));

        var passengers = new List<HttpClient>();
        for (var i = 0; i < 4; i++)
            passengers.Add((await SignUpAsync(Gender.Male, asDriver: false)).Client);

        var responses = await Task.WhenAll(passengers.Select(p =>
            p.PostAsJsonAsync($"/v1/trips/{trip.Id}/bookings", new CreateBookingRequest(1, PaymentMethod.Cash), ApiFactory.Json)));

        Assert.Equal(1, responses.Count(r => r.StatusCode == HttpStatusCode.Created));
        Assert.All(responses.Where(r => r.StatusCode != HttpStatusCode.Created),
            r => Assert.Equal(HttpStatusCode.Conflict, r.StatusCode));

        var details = await driver.GetFromJsonAsync<TripDetailsResponse>($"/v1/trips/{trip.Id}", ApiFactory.Json);
        Assert.Equal(0, details!.Trip.SeatsAvailable);
    }

    [Fact]
    public async Task Unverified_user_cannot_publish_a_trip()
    {
        var (client, _) = await SignUpAsync(Gender.Male, asDriver: false);
        var vehicle = await client.PostAsync<VehicleResponse>("/v1/me/vehicles",
            new CreateVehicleRequest("Toyota", "Yaris", "Rouge", NextPlate(), 4));

        var response = await client.PostAsJsonAsync("/v1/trips", NewTrip(vehicle.Id, 2, api.Clock.GetUtcNow().AddDays(1)), ApiFactory.Json);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("verification.driver_not_verified", await response.ErrorCodeAsync());
    }

    [Fact]
    public async Task Admin_endpoints_require_the_admin_group()
    {
        var (user, _) = await SignUpAsync(Gender.Male, asDriver: false);
        Assert.Equal(HttpStatusCode.Forbidden, (await user.GetAsync("/v1/admin/stats")).StatusCode);

        var admin = api.ClientFor("admin-sub", NextPhone(), admin: true);
        var stats = await admin.GetFromJsonAsync<StatsResponse>("/v1/admin/stats", ApiFactory.Json);
        Assert.True(stats!.Users > 0);

        Assert.Equal(HttpStatusCode.Unauthorized, (await api.CreateClient().GetAsync("/v1/me")).StatusCode);
    }

    private async Task<(HttpClient Client, ProfileResponse Profile)> SignUpAsync(Gender gender, bool asDriver)
    {
        var client = api.ClientFor($"sub-{Guid.NewGuid()}", NextPhone());
        await (await client.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Test", "User", gender, Language.French), ApiFactory.Json)).ReadAsync<ProfileResponse>();

        var required = new VerificationRequirements();
        foreach (var type in asDriver ? required.Driver : required.Passenger)
        {
            var created = await client.PostAsync<CreateDocumentResponse>("/v1/me/documents", new CreateDocumentRequest(type, "image/jpeg"));
            DateOnly? expiry = UserDocument.RequiresExpiryDate(type) ? new DateOnly(2028, 1, 1) : null;
            await client.PostAsync<DocumentResponse>($"/v1/me/documents/{created.DocumentId}/submit", new SubmitDocumentRequest(expiry));
        }

        var profile = await client.GetFromJsonAsync<ProfileResponse>("/v1/me", ApiFactory.Json);
        Assert.Equal(VerificationStatus.Verified, profile!.Passenger.Status);
        Assert.Equal(asDriver ? VerificationStatus.Verified : VerificationStatus.Incomplete, profile.Driver.Status);
        return (client, profile);
    }

    private static async Task<TripResponse> PublishDoualaYaoundeAsync(HttpClient driver, int seats, DateTimeOffset departure)
    {
        var vehicle = await driver.PostAsync<VehicleResponse>("/v1/me/vehicles",
            new CreateVehicleRequest("Toyota", "Corolla", "Grise", NextPlate(), 4));
        return await driver.PostAsync<TripResponse>("/v1/trips", NewTrip(vehicle.Id, seats, departure));
    }

    private static PublishTripRequest NewTrip(Guid vehicleId, int seats, DateTimeOffset departure) => new(
        vehicleId, TripKind.Intercity,
        new LocationDto("Douala", "Carrefour Ndokoti", 4.0511, 9.7679),
        new LocationDto("Yaoundé", "Total Mvan", 3.8480, 11.5021),
        departure, seats, 5000, WomenOnly: false, LuggageAllowed: true, SmokingAllowed: false, InstantBooking: true, Notes: null);

    private static string NextPhone() => $"+2376900{Interlocked.Increment(ref _phoneCounter):D5}";

    private static string NextPlate() => $"LT{Guid.NewGuid().ToString("N")[..6].ToUpperInvariant()}";
}
