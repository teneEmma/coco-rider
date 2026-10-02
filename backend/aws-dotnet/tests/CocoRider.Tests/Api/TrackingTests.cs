using System.Net;
using System.Net.Http.Json;
using CocoRider.Api.Features.Bookings;
using CocoRider.Api.Features.Notifications;
using CocoRider.Api.Features.Tracking;
using CocoRider.Api.Features.Trips;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Notifications;
using CocoRider.Domain.Users;
using Microsoft.Extensions.DependencyInjection;

namespace CocoRider.Tests.Api;

public class TrackingTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    // A point on the Douala–Yaoundé road, near Edéa.
    private static readonly UpdatePositionRequest NearEdea = new(3.80, 10.13, 90, 72, DateTimeOffset.MinValue);

    [Fact]
    public async Task Passengers_follow_the_driver_live()
    {
        var driver = await TestUsers.SignUpAsync(api, Language.French, asDriver: true, firstName: "Paul");
        var passenger = await TestUsers.SignUpAsync(api, Language.French, asDriver: false);
        var waiting = await TestUsers.SignUpAsync(api, Language.French, asDriver: false);
        var outsider = await TestUsers.SignUpAsync(api, Language.French, asDriver: false);
        await passenger.PutAsJsonAsync("/v1/me/devices", new RegisterDeviceRequest("tracking-passenger", DevicePlatform.Android), ApiFactory.Json);

        var departure = api.Clock.GetUtcNow().AddHours(2);
        var instant = await TestUsers.PublishTripAsync(driver, instantBooking: true, departure);
        await passenger.PostAsync<BookingResponse>($"/v1/trips/{instant.Id}/bookings", new CreateBookingRequest(1, PaymentMethod.Cash));

        // Too early: sharing opens one hour before departure.
        var early = await driver.PutAsJsonAsync($"/v1/trips/{instant.Id}/position", Now(NearEdea), ApiFactory.Json);
        Assert.Equal("tracking.not_active", await early.ErrorCodeAsync());

        api.Clock.Advance(TimeSpan.FromMinutes(90));
        var before = await passenger.GetFromJsonAsync<TrackingResponse>($"/v1/trips/{instant.Id}/position", ApiFactory.Json);
        Assert.Null(before!.Position);

        Assert.Equal(HttpStatusCode.NoContent, (await driver.PutAsJsonAsync($"/v1/trips/{instant.Id}/position", Now(NearEdea), ApiFactory.Json)).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await driver.PutAsJsonAsync($"/v1/trips/{instant.Id}/position", Now(NearEdea), ApiFactory.Json)).StatusCode);

        var push = await api.Push.WaitForAsync("tracking-passenger", m => m.Data["kind"] == nameof(NotificationKind.TripStarted));
        Assert.Equal("Paul est en route", push.Title);
        await Task.Delay(300);
        Assert.Single(api.Push.Sent, s => s.Tokens.Contains("tracking-passenger") && s.Message.Data["kind"] == nameof(NotificationKind.TripStarted));

        var tracking = await passenger.GetFromJsonAsync<TrackingResponse>($"/v1/trips/{instant.Id}/position", ApiFactory.Json);
        Assert.NotNull(tracking!.Position);
        Assert.True(tracking.Position.IsLive);
        Assert.Equal(3.80, tracking.Position.Latitude);
        Assert.InRange(tracking.Position.DistanceToDestinationKm, 150, 160); // Edéa → Yaoundé as the crow flies.

        // Older positions arriving late are ignored.
        await driver.PutAsJsonAsync($"/v1/trips/{instant.Id}/position",
            NearEdea with { Latitude = 4.0, RecordedAt = api.Clock.GetUtcNow().AddMinutes(-5) }, ApiFactory.Json);
        tracking = await passenger.GetFromJsonAsync<TrackingResponse>($"/v1/trips/{instant.Id}/position", ApiFactory.Json);
        Assert.Equal(3.80, tracking!.Position!.Latitude);

        // Three minutes without update: shown as "last seen".
        api.Clock.Advance(TimeSpan.FromMinutes(3));
        tracking = await passenger.GetFromJsonAsync<TrackingResponse>($"/v1/trips/{instant.Id}/position", ApiFactory.Json);
        Assert.False(tracking!.Position!.IsLive);

        Assert.Equal(HttpStatusCode.NotFound, (await outsider.GetAsync($"/v1/trips/{instant.Id}/position")).StatusCode);

        // A passenger whose request is still pending cannot follow the driver.
        var onRequest = await TestUsers.PublishTripAsync(driver, instantBooking: false, departure.AddHours(1));
        await waiting.PostAsync<BookingResponse>($"/v1/trips/{onRequest.Id}/bookings", new CreateBookingRequest(1, PaymentMethod.Cash));
        Assert.Equal(HttpStatusCode.NotFound, (await waiting.GetAsync($"/v1/trips/{onRequest.Id}/position")).StatusCode);

        // The driver stops sharing.
        Assert.Equal(HttpStatusCode.NoContent, (await driver.DeleteAsync($"/v1/trips/{instant.Id}/position")).StatusCode);
        tracking = await passenger.GetFromJsonAsync<TrackingResponse>($"/v1/trips/{instant.Id}/position", ApiFactory.Json);
        Assert.Null(tracking!.Position);
    }

    [Fact]
    public async Task Relatives_follow_a_shared_trip_until_the_link_expires()
    {
        var driver = await TestUsers.SignUpAsync(api, Language.French, asDriver: true, firstName: "Paul");
        var passenger = await TestUsers.SignUpAsync(api, Language.French, asDriver: false);
        var trip = await TestUsers.PublishTripAsync(driver, instantBooking: true, api.Clock.GetUtcNow().AddMinutes(40));
        await passenger.PostAsync<BookingResponse>($"/v1/trips/{trip.Id}/bookings", new CreateBookingRequest(1, PaymentMethod.Cash));
        await driver.PutAsJsonAsync($"/v1/trips/{trip.Id}/position", Now(NearEdea), ApiFactory.Json);

        var share = await passenger.PostAsync<ShareResponse>($"/v1/trips/{trip.Id}/shares");
        Assert.EndsWith($"/suivi/{share.Token}", share.Url.ToString());
        Assert.True(share.Token.Length >= 40);

        // No account needed to open the link.
        var anonymous = api.CreateClient();
        var shared = await anonymous.GetFromJsonAsync<SharedTripResponse>($"/v1/shared/{share.Token}", ApiFactory.Json);
        Assert.Equal("Paul", shared!.DriverFirstName);
        Assert.Equal("Toyota", shared.Vehicle.Make);
        Assert.StartsWith("LT", shared.Vehicle.PlateNumber);
        Assert.NotNull(shared.Position);
        Assert.Equal(HttpStatusCode.NotFound, (await anonymous.GetAsync("/v1/shared/not-a-real-token")).StatusCode);

        // Once the trip is over, the position is deleted.
        api.Clock.Advance(TimeSpan.FromHours(13));
        using (var scope = api.Services.CreateScope())
            await scope.ServiceProvider.GetRequiredService<TripLifecycle>().RunAsync(CancellationToken.None);
        shared = await anonymous.GetFromJsonAsync<SharedTripResponse>($"/v1/shared/{share.Token}", ApiFactory.Json);
        Assert.Null(shared!.Position);

        // The link expires 24 hours after departure.
        api.Clock.Advance(TimeSpan.FromHours(12));
        Assert.Equal(HttpStatusCode.NotFound, (await anonymous.GetAsync($"/v1/shared/{share.Token}")).StatusCode);
    }

    private UpdatePositionRequest Now(UpdatePositionRequest position) => position with { RecordedAt = api.Clock.GetUtcNow() };
}
