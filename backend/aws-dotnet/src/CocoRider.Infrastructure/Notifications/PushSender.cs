using System.Text.Json;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CocoRider.Infrastructure.Notifications;

public sealed class NotificationOptions
{
    /// <summary>
    /// Content of the Firebase service account key (JSON). Without a valid key, notifications
    /// are only written to the logs (local development, or before Firebase is configured).
    /// </summary>
    public string FcmServiceAccountJson { get; set; } = "";
}

/// <summary>A rendered push notification for a set of devices.</summary>
public sealed record PushMessage(string Title, string Body, IReadOnlyDictionary<string, string> Data);

public interface IPushSender
{
    /// <summary>Sends the message and returns the tokens Firebase reports as no longer valid.</summary>
    Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct);
}

/// <summary>Firebase Cloud Messaging (free) for Android and iOS.</summary>
public sealed class FcmPushSender(FirebaseMessaging messaging, ILogger<FcmPushSender> logger) : IPushSender
{
    public async Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct)
    {
        if (tokens.Count == 0)
            return [];

        // The app sends FCM registration tokens (firebase_messaging getToken), still supported by FCM;
        // the SDK marks them obsolete in favour of installation IDs, which the app does not use yet.
#pragma warning disable CS0618
        var response = await messaging.SendEachForMulticastAsync(new MulticastMessage
        {
            Tokens = tokens.ToList(),
            Notification = new Notification { Title = message.Title, Body = message.Body },
            Data = message.Data,
            Android = new AndroidConfig { Priority = Priority.High },
            Apns = new ApnsConfig { Aps = new Aps { Sound = "default" } },
        }, ct);
#pragma warning restore CS0618

        var invalid = new List<string>();
        for (var i = 0; i < response.Responses.Count; i++)
        {
            var result = response.Responses[i];
            if (result.IsSuccess)
                continue;

            if (result.Exception?.MessagingErrorCode is MessagingErrorCode.Unregistered or MessagingErrorCode.InvalidArgument)
                invalid.Add(tokens[i]);
            else
                logger.LogWarning(result.Exception, "Push notification failed");
        }
        return invalid;
    }

    /// <summary>Returns null when the key is missing or not a service account key.</summary>
    public static FirebaseMessaging? TryCreateMessaging(NotificationOptions options, ILogger logger)
    {
        var json = options.FcmServiceAccountJson;
        if (string.IsNullOrWhiteSpace(json) || !LooksLikeServiceAccount(json))
        {
            logger.LogWarning("No Firebase service account key configured: push notifications are only logged.");
            return null;
        }

        var credential = CredentialFactory.FromJson<ServiceAccountCredential>(json).ToGoogleCredential();
        var app = FirebaseApp.GetInstance("coco-rider") ?? FirebaseApp.Create(new AppOptions { Credential = credential }, "coco-rider");
        return FirebaseMessaging.GetMessaging(app);
    }

    private static bool LooksLikeServiceAccount(string json)
    {
        try
        {
            using var document = JsonDocument.Parse(json);
            return document.RootElement.TryGetProperty("type", out var type) && type.GetString() == "service_account"
                && document.RootElement.TryGetProperty("private_key", out _);
        }
        catch (JsonException)
        {
            return false;
        }
    }
}

/// <summary>Local development and tests: notifications are logged instead of sent.</summary>
public sealed class LoggingPushSender(ILogger<LoggingPushSender> logger) : IPushSender
{
    public Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct)
    {
        logger.LogInformation("Push to {Count} device(s): {Title} – {Body}", tokens.Count, message.Title, message.Body);
        return Task.FromResult<IReadOnlyList<string>>([]);
    }
}
