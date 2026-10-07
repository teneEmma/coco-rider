using System.Net;
using System.Net.Http.Json;
using CocoRider.Api.Features.Bookings;
using CocoRider.Api.Features.Messaging;
using CocoRider.Api.Features.Notifications;
using CocoRider.Domain.Bookings;
using CocoRider.Domain.Notifications;
using CocoRider.Domain.Users;

namespace CocoRider.Tests.Api;

public class ChatTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task Passenger_and_driver_chat_about_a_booking()
    {
        var driver = await TestUsers.SignUpAsync(api, Language.French, asDriver: true, firstName: "Paul");
        var passenger = await TestUsers.SignUpAsync(api, Language.French, asDriver: false, firstName: "Ama");
        await driver.PutAsJsonAsync("/v1/me/devices", new RegisterDeviceRequest("chat-driver-phone", DevicePlatform.Android), ApiFactory.Json);

        var trip = await TestUsers.PublishTripAsync(driver, instantBooking: true, api.Clock.GetUtcNow().AddDays(2));
        var booking = await passenger.PostAsync<BookingResponse>($"/v1/trips/{trip.Id}/bookings", new CreateBookingRequest(1, PaymentMethod.Cash));

        var sent = await passenger.PostAsync<MessageResponse>($"/v1/bookings/{booking.Id}/messages",
            new SendMessageRequest("  Bonjour, je serai au carrefour avec un sac bleu.  "));
        Assert.True(sent.FromMe);
        Assert.Equal("Bonjour, je serai au carrefour avec un sac bleu.", sent.Body);

        // The driver gets a push notification with the sender's name and the text.
        var push = await api.Push.WaitForAsync("chat-driver-phone", m => m.Data["kind"] == nameof(NotificationKind.NewMessage));
        Assert.Equal("Message de Ama", push.Title);
        Assert.Equal(booking.Id.ToString(), push.Data["bookingId"]);

        var driverInbox = await driver.GetFromJsonAsync<List<ConversationSummary>>("/v1/me/conversations", ApiFactory.Json);
        var summary = Assert.Single(driverInbox!);
        Assert.Equal(1, summary.Unread);
        Assert.Equal("Ama", summary.With.FirstName);
        Assert.Equal("Douala", summary.From);

        // Opening the conversation marks the message as read.
        var conversation = await driver.GetFromJsonAsync<ConversationResponse>($"/v1/bookings/{booking.Id}/messages", ApiFactory.Json);
        Assert.True(conversation!.CanWrite);
        Assert.False(Assert.Single(conversation.Messages).FromMe);
        driverInbox = await driver.GetFromJsonAsync<List<ConversationSummary>>("/v1/me/conversations", ApiFactory.Json);
        Assert.Equal(0, driverInbox!.Single().Unread);

        api.Clock.Advance(TimeSpan.FromMinutes(1));
        await driver.PostAsync<MessageResponse>($"/v1/bookings/{booking.Id}/messages", new SendMessageRequest("D'accord, à demain !"));

        // Polling only returns what is new.
        var newer = await passenger.GetFromJsonAsync<ConversationResponse>(
            $"/v1/bookings/{booking.Id}/messages?after={Uri.EscapeDataString(sent.SentAt.ToString("O"))}", ApiFactory.Json);
        var reply = Assert.Single(newer!.Messages);
        Assert.Equal("D'accord, à demain !", reply.Body);
        Assert.Equal("Paul", newer.With.FirstName);
    }

    [Fact]
    public async Task Only_participants_can_read_and_closed_conversations_are_read_only()
    {
        var driver = await TestUsers.SignUpAsync(api, Language.French, asDriver: true);
        var passenger = await TestUsers.SignUpAsync(api, Language.French, asDriver: false);
        var outsider = await TestUsers.SignUpAsync(api, Language.French, asDriver: false);
        var trip = await TestUsers.PublishTripAsync(driver, instantBooking: false, api.Clock.GetUtcNow().AddDays(2));
        var booking = await passenger.PostAsync<BookingResponse>($"/v1/trips/{trip.Id}/bookings", new CreateBookingRequest(1, PaymentMethod.Cash));

        Assert.Equal(HttpStatusCode.NotFound, (await outsider.GetAsync($"/v1/bookings/{booking.Id}/messages")).StatusCode);

        var empty = await passenger.PostAsJsonAsync($"/v1/bookings/{booking.Id}/messages", new SendMessageRequest("   "), ApiFactory.Json);
        Assert.Equal("message.empty", await empty.ErrorCodeAsync());

        await driver.PostAsync<BookingResponse>($"/v1/bookings/{booking.Id}/reject");

        var closed = await passenger.PostAsJsonAsync($"/v1/bookings/{booking.Id}/messages", new SendMessageRequest("Pourquoi ?"), ApiFactory.Json);
        Assert.Equal(HttpStatusCode.Conflict, closed.StatusCode);
        Assert.Equal("message.conversation_closed", await closed.ErrorCodeAsync());
        var conversation = await passenger.GetFromJsonAsync<ConversationResponse>($"/v1/bookings/{booking.Id}/messages", ApiFactory.Json);
        Assert.False(conversation!.CanWrite);
    }
}
