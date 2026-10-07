using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Time.Testing;
using Testcontainers.PostgreSql;
using CocoRider.Infrastructure.Notifications;
using System.Collections.Concurrent;

namespace CocoRider.Tests.Api;

/// <summary>Runs the real API against a throw-away PostGIS container (Docker required).</summary>
public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgis/postgis:16-3.4-alpine").Build();

    /// <summary>Every push notification the API tried to send.</summary>
    public RecordingPushSender Push { get; } = new();

    public FakeTimeProvider Clock { get; } = new(new DateTimeOffset(2026, 10, 1, 7, 0, 0, TimeSpan.Zero));

    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    public Task InitializeAsync() => _postgres.StartAsync();

    public new Task DisposeAsync() => _postgres.DisposeAsync().AsTask();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.UseSetting("ConnectionStrings:Postgres", _postgres.GetConnectionString());
        builder.UseSetting("Auth:Mode", "Development");
        builder.UseSetting("Storage:Mode", "Fake");
        builder.UseSetting("Database:MigrateOnStartup", "true");
        builder.UseSetting("Lifecycle:Enabled", "false");
        builder.ConfigureServices(services =>
        {
            services.Replace(ServiceDescriptor.Singleton<TimeProvider>(Clock));
            services.Replace(ServiceDescriptor.Singleton<IPushSender>(Push));
        });
    }

    /// <summary>A client authenticated as the given Cognito user.</summary>
    public HttpClient ClientFor(string sub, string phone, bool admin = false)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-User", sub);
        client.DefaultRequestHeaders.Add("X-Dev-Phone", phone);
        if (admin)
            client.DefaultRequestHeaders.Add("X-Dev-Groups", "admin");
        return client;
    }

    /// <summary>A client authenticated as a Cognito user who signed in with an email code (no verified phone).</summary>
    public HttpClient EmailClientFor(string sub, string email)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-User", sub);
        client.DefaultRequestHeaders.Add("X-Dev-Email", email);
        return client;
    }
}

internal static class HttpExtensions
{
    public static async Task<T> ReadAsync<T>(this HttpResponseMessage response)
    {
        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException($"{(int)response.StatusCode}: {await response.Content.ReadAsStringAsync()}");
        return (await response.Content.ReadFromJsonAsync<T>(ApiFactory.Json))!;
    }

    public static async Task<T> PostAsync<T>(this HttpClient client, string url, object? body = null) =>
        await (await client.PostAsJsonAsync(url, body ?? new { }, ApiFactory.Json)).ReadAsync<T>();

    public static async Task<string?> ErrorCodeAsync(this HttpResponseMessage response)
    {
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return json.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }
}

public sealed class RecordingPushSender : IPushSender
{
    public ConcurrentQueue<(IReadOnlyList<string> Tokens, PushMessage Message)> Sent { get; } = new();

    /// <summary>Tokens reported to the API as no longer valid.</summary>
    public ConcurrentDictionary<string, bool> InvalidTokens { get; } = new();

    public Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct)
    {
        Sent.Enqueue((tokens, message));
        return Task.FromResult<IReadOnlyList<string>>(tokens.Where(InvalidTokens.ContainsKey).ToList());
    }

    /// <summary>Waits for the background dispatcher to send a message to the token.</summary>
    public async Task<PushMessage> WaitForAsync(string token, Func<PushMessage, bool> match)
    {
        for (var i = 0; i < 100; i++)
        {
            var found = Sent.FirstOrDefault(s => s.Tokens.Contains(token) && match(s.Message));
            if (found.Message is not null)
                return found.Message;
            await Task.Delay(50);
        }
        throw new TimeoutException($"No push notification for {token}");
    }
}
