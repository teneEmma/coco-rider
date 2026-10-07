using System.Net.Http.Json;
using CocoRider.Api.Features.Profile;
using CocoRider.Domain.Users;

namespace CocoRider.Tests.Api;

public class EmailSignInTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    private static string NewPhone() => $"+2376{Random.Shared.Next(10_000_000, 99_999_999)}";

    [Fact]
    public async Task Email_user_creates_a_profile_with_a_typed_phone_number()
    {
        var email = $"ama-{Guid.NewGuid():N}@example.com";
        var client = api.EmailClientFor($"sub-{Guid.NewGuid()}", email);
        var phone = NewPhone();

        var profile = await (await client.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Ama", "Ngo", Language.French, phone[4..]), ApiFactory.Json))
            .ReadAsync<ProfileResponse>();

        Assert.Equal(phone, profile.PhoneNumber);
        Assert.False(profile.PhoneVerified);
        Assert.Equal(email, profile.Email);

        // The typed number can be corrected later.
        var corrected = NewPhone();
        profile = await (await client.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Ama", "Ngo", Language.French, corrected), ApiFactory.Json))
            .ReadAsync<ProfileResponse>();
        Assert.Equal(corrected, profile.PhoneNumber);
    }

    [Fact]
    public async Task Email_user_needs_a_phone_number_that_is_not_taken()
    {
        var client = api.EmailClientFor($"sub-{Guid.NewGuid()}", $"x-{Guid.NewGuid():N}@example.com");

        var missing = await client.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Ama", "Ngo", Language.French), ApiFactory.Json);
        Assert.Equal("profile.invalid_phone", await missing.ErrorCodeAsync());

        var phone = NewPhone();
        var smsUser = api.ClientFor($"sub-{Guid.NewGuid()}", phone);
        await (await smsUser.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Paul", "Mbia", Language.French), ApiFactory.Json)).ReadAsync<ProfileResponse>();

        var taken = await client.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Ama", "Ngo", Language.French, phone), ApiFactory.Json);
        Assert.Equal("profile.phone_taken", await taken.ErrorCodeAsync());
    }

    [Fact]
    public async Task Sms_verified_number_cannot_be_replaced()
    {
        var phone = NewPhone();
        var client = api.ClientFor($"sub-{Guid.NewGuid()}", phone);
        await (await client.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Paul", "Mbia", Language.French), ApiFactory.Json)).ReadAsync<ProfileResponse>();

        var profile = await (await client.PutAsJsonAsync("/v1/me",
            new UpsertProfileRequest("Paul", "Mbia", Language.French, NewPhone()), ApiFactory.Json))
            .ReadAsync<ProfileResponse>();

        Assert.Equal(phone, profile.PhoneNumber);
        Assert.True(profile.PhoneVerified);
    }
}
