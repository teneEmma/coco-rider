using System.Net.Http.Json;
using CocoRider.Api.Features.Documents;
using CocoRider.Api.Features.Profile;
using CocoRider.Api.Features.Trips;
using CocoRider.Api.Features.Vehicles;
using CocoRider.Domain.Trips;
using CocoRider.Domain.Users;
using CocoRider.Domain.Verification;

namespace CocoRider.Tests.Api;

/// <summary>Creates verified users and trips through the API.</summary>
internal static class TestUsers
{
    private static int _phone = 50_000;

    public static async Task<HttpClient> SignUpAsync(ApiFactory api, Language language, bool asDriver, string firstName = "Test")
    {
        var client = api.ClientFor($"sub-{Guid.NewGuid()}", $"+2376800{Interlocked.Increment(ref _phone):D5}");
        await (await client.PutAsJsonAsync("/v1/me", new UpsertProfileRequest(firstName, "User", language), ApiFactory.Json))
            .ReadAsync<ProfileResponse>();

        var required = new VerificationRequirements();
        foreach (var type in asDriver ? required.Driver : required.Passenger)
        {
            var created = await client.PostAsync<CreateDocumentResponse>("/v1/me/documents",
                new CreateDocumentRequest(type, "image/jpeg"));
            DateOnly? expiry = UserDocument.RequiresExpiryDate(type) ? new DateOnly(2028, 1, 1) : null;
            await client.PostAsync<DocumentResponse>(
                $"/v1/me/documents/{created.DocumentId}/submit", new SubmitDocumentRequest(expiry));
        }
        return client;
    }

    public static async Task<TripResponse> PublishTripAsync(HttpClient driver, bool instantBooking, DateTimeOffset departure)
    {
        var vehicle = await driver.PostAsync<VehicleResponse>("/v1/me/vehicles",
            new CreateVehicleRequest("Toyota", "Corolla", "Grise", $"LT{Guid.NewGuid().ToString("N")[..6]}", 4));
        return await driver.PostAsync<TripResponse>("/v1/trips", new PublishTripRequest(
            vehicle.Id, TripKind.Intercity,
            new LocationDto("Douala", "Ndokoti", 4.05, 9.77), new LocationDto("Yaoundé", "Mvan", 3.85, 11.50),
            departure, 3, 5000,
            LuggageAllowed: true, SmokingAllowed: false, InstantBooking: instantBooking, Notes: null));
    }
}
