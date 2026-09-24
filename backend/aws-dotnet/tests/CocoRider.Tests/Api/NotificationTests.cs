using System.Net;
using System.Net.Http.Json;
using CocoRider.Api.Features.Bookings;
using CocoRider.Api.Features.Notifications;
using CocoRider.Api.Features.Profile;
using CocoRider.Api.Features.Trips;
using CocoRider.Api.Features.Vehicles;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Notifications;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace CocoRider.Tests.Api;

public class NotificationTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    private static int _phone = 50_000;

    [Fact]
    public async Task Driver_and_passenger_are_notified_in_their_language()
    {
        var driver = await SignUpAsync(Language.French, asDriver: true);
        var passenger = await SignUpAsync(Language.English, asDriver: false);
        await RegisterAsync(driver, "driver-phone");
        await RegisterAsync(passenger, "passenger-phone");

        var vehicle = await driver.PostAsync<VehicleResponse>("/v1/me/vehicles",
            new CreateVehicleRequest("Toyota", "Corolla", "Grise", $"LT{Guid.NewGuid().ToString("N")[..6]}", 4));
        var trip = await driver.PostAsync<TripResponse>("/v1/trips", new PublishTripRequest(
            vehicle.Id, TripKind.Intercity,
            new LocationDto("Douala", "Ndokoti", 4.05, 9.77), new LocationDto("Yaoundé", "Mvan", 3.85, 11.50),
            new DateTimeOffset(2026, 10, 5, 6, 30, 0, TimeSpan.Zero), 3, 5000,
            WomenOnly: false, LuggageAllowed: true, SmokingAllowed: false, InstantBooking: false, Notes: null));

        var booking = await passenger.PostAsync<BookingResponse>($"/v1/trips/{trip.Id}/bookings", new CreateBookingRequest(2, PaymentMethod.Cash));

        var toDriver = await api.Push.WaitForAsync("driver-phone", m => m.Data["kind"] == nameof(NotificationKind.NewBookingRequest));
        Assert.Equal("Nouvelle demande", toDriver.Title);
        Assert.Equal("Test demande 2 place(s) pour Douala → Yaoundé le 05/10 07:30. Acceptez ou refusez.", toDriver.Body);
        Assert.Equal(booking.Id.ToString(), toDriver.Data["bookingId"]);
        Assert.Equal(trip.Id.ToString(), toDriver.Data["tripId"]);

        await driver.PostAsync<BookingResponse>($"/v1/bookings/{booking.Id}/accept");

        var toPassenger = await api.Push.WaitForAsync("passenger-phone", m => m.Data["kind"] == nameof(NotificationKind.BookingAccepted));
        Assert.Equal("Booking confirmed", toPassenger.Title);
        Assert.Equal("Your seat for Douala → Yaoundé on 05/10 07:30 is confirmed.", toPassenger.Body);
    }

    [Fact]
    public async Task Tokens_move_with_sign_in_and_invalid_ones_are_removed()
    {
        var first = await SignUpAsync(Language.French, asDriver: false);
        var second = await SignUpAsync(Language.French, asDriver: false);

        // The same phone is used by two accounts one after the other: it belongs to the last one.
        await RegisterAsync(first, "shared-phone");
        await RegisterAsync(second, "shared-phone");
        Assert.Equal(1, await CountTokensAsync("shared-phone"));

        // Firebase reports the token as unregistered: it is deleted after the next send.
        api.Push.InvalidTokens["shared-phone"] = true;
        using (var scope = api.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<CocoRiderDbContext>();
            var owner = await db.DeviceTokens.Where(d => d.Token == "shared-phone").Select(d => d.UserId).SingleAsync();
            scope.ServiceProvider.GetRequiredService<NotificationQueue>().Enqueue(new PushNotification(
                owner, NotificationKind.DocumentApproved, new Dictionary<string, string> { ["document"] = "NationalId" }));
        }

        var message = await api.Push.WaitForAsync("shared-phone", m => m.Data["kind"] == nameof(NotificationKind.DocumentApproved));
        Assert.Equal("Votre document « CNI » a été accepté.", message.Body);
        for (var i = 0; i < 50 && await CountTokensAsync("shared-phone") > 0; i++)
            await Task.Delay(50);
        Assert.Equal(0, await CountTokensAsync("shared-phone"));

        var signOut = await second.DeleteAsync("/v1/me/devices/unknown-token");
        Assert.Equal(HttpStatusCode.NoContent, signOut.StatusCode);
    }

    private async Task<int> CountTokensAsync(string token)
    {
        using var scope = api.Services.CreateScope();
        return await scope.ServiceProvider.GetRequiredService<CocoRiderDbContext>().DeviceTokens.CountAsync(d => d.Token == token);
    }

    private static async Task RegisterAsync(HttpClient client, string token)
    {
        var response = await client.PutAsJsonAsync("/v1/me/devices", new RegisterDeviceRequest(token, DevicePlatform.Android), ApiFactory.Json);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    private async Task<HttpClient> SignUpAsync(Language language, bool asDriver)
    {
        var client = api.ClientFor($"sub-{Guid.NewGuid()}", $"+2376800{Interlocked.Increment(ref _phone):D5}");
        await (await client.PutAsJsonAsync("/v1/me", new UpsertProfileRequest("Test", "User", Gender.Female, language), ApiFactory.Json))
            .ReadAsync<ProfileResponse>();

        var required = new VerificationRequirements();
        foreach (var type in asDriver ? required.Driver : required.Passenger)
        {
            var created = await client.PostAsync<CocoRider.Api.Features.Documents.CreateDocumentResponse>("/v1/me/documents",
                new CocoRider.Api.Features.Documents.CreateDocumentRequest(type, "image/jpeg"));
            DateOnly? expiry = UserDocument.RequiresExpiryDate(type) ? new DateOnly(2028, 1, 1) : null;
            await client.PostAsync<CocoRider.Api.Features.Documents.DocumentResponse>(
                $"/v1/me/documents/{created.DocumentId}/submit", new CocoRider.Api.Features.Documents.SubmitDocumentRequest(expiry));
        }
        return client;
    }
}
